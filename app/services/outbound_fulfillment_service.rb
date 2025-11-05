class OutboundFulfillmentService
  attr_reader :fulfillment, :order, :store, :errors

  def initialize(fulfillment:)
    @fulfillment = fulfillment
    @order = fulfillment.order
    @store = order.store
    @errors = []
  end

  def sync_to_shopify
    # Only sync Shopify orders
    return { success: false, message: "Not a Shopify order" } unless store.platform == "shopify"
    return { success: false, message: "Missing external order ID" } unless order.external_id.present?

    # Block sync for inactive stores
    unless store.active?
      Rails.logger.warn "Attempted to sync fulfillment for inactive store: #{store.name}"
      return { success: false, message: "Store is inactive" }
    end

    begin
      # Step 1: Fetch fulfillment orders from Shopify
      shopify_order_data = fetch_shopify_fulfillment_orders
      return { success: false, message: "No fulfillment orders found" } unless shopify_order_data

      # Step 2: Build line items payload
      line_items_payload = build_line_items_payload(shopify_order_data)
      return { success: false, message: "No matching line items found" } if line_items_payload.empty?

      # Step 3: Create fulfillment in Shopify
      result = create_shopify_fulfillment(line_items_payload)

      if result[:success]
        log_success_activity(result[:shopify_fulfillment_id])
        { success: true, shopify_fulfillment_id: result[:shopify_fulfillment_id] }
      else
        log_error_activity(result[:error])
        { success: false, error: result[:error] }
      end
    rescue StandardError => e
      Rails.logger.error "OutboundFulfillmentService error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      log_error_activity(e.message)
      { success: false, error: e.message }
    end
  end

  private

  def fetch_shopify_fulfillment_orders
    query = <<~GRAPHQL
      query($orderId: ID!) {
        order(id: $orderId) {
          id
          fulfillmentOrders(first: 10, query: "status:open OR status:in_progress") {
            edges {
              node {
                id
                status
                lineItems(first: 50) {
                  edges {
                    node {
                      id
                      lineItem {
                        id
                      }
                      remainingQuantity
                    }
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL

    variables = {
      orderId: "gid://shopify/Order/#{order.external_id}"
    }

    response = shopify_client.query(query: query, variables: variables)

    if response.body.dig("data", "order")
      response.body["data"]["order"]
    else
      Rails.logger.error "Failed to fetch Shopify order: #{response.body.dig('errors')}"
      nil
    end
  end

  def build_line_items_payload(shopify_order_data)
    fulfillment_orders = shopify_order_data.dig("fulfillmentOrders", "edges") || []
    line_items_by_fulfillment_order = []

    fulfillment_orders.each do |fo_edge|
      fo_node = fo_edge["node"]
      fulfillment_order_id = fo_node["id"]
      shopify_line_items = fo_node.dig("lineItems", "edges") || []

      # Match our fulfillment line items to Shopify fulfillment order line items
      fulfillment_order_line_items = []

      fulfillment.fulfillment_line_items.each do |fli|
        order_item = fli.order_item
        
        # Skip custom order items - they don't exist in the Shopify store
        next if order_item.is_custom?
        
        # Use external_line_id for matching to original Shopify store line items
        shopify_line_item_id = order_item.external_line_id

        next unless shopify_line_item_id.present?

        # Find matching Shopify fulfillment order line item
        matching_fo_line_item = shopify_line_items.find do |sli_edge|
          sli_node = sli_edge["node"]
          sli_node.dig("lineItem", "id") == "gid://shopify/LineItem/#{shopify_line_item_id}"
        end

        if matching_fo_line_item
          fo_line_item_id = matching_fo_line_item["node"]["id"]
          remaining_qty = matching_fo_line_item["node"]["remainingQuantity"]

          # Only add if there's remaining quantity to fulfill
          if remaining_qty >= fli.quantity
            fulfillment_order_line_items << {
              id: fo_line_item_id,
              quantity: fli.quantity
            }
          else
            Rails.logger.warn "Insufficient remaining quantity for FO line item #{fo_line_item_id}: need #{fli.quantity}, have #{remaining_qty}"
          end
        else
          Rails.logger.warn "Could not match order_item #{order_item.id} to Shopify fulfillment order line item"
        end
      end

      # Add to payload if we have items for this fulfillment order
      if fulfillment_order_line_items.any?
        line_items_by_fulfillment_order << {
          fulfillmentOrderId: fulfillment_order_id,
          fulfillmentOrderLineItems: fulfillment_order_line_items
        }
      end
    end

    line_items_by_fulfillment_order
  end

  def create_shopify_fulfillment(line_items_payload)
    mutation = <<~GRAPHQL
      mutation fulfillmentCreate($fulfillment: FulfillmentInput!) {
        fulfillmentCreate(fulfillment: $fulfillment) {
          fulfillment {
            id
            status
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL

    # Build tracking info
    tracking_info = {}
    tracking_info[:company] = fulfillment.tracking_company if fulfillment.tracking_company.present?
    tracking_info[:number] = fulfillment.tracking_number if fulfillment.tracking_number.present?
    tracking_info[:url] = fulfillment.tracking_url if fulfillment.tracking_url.present?

    variables = {
      fulfillment: {
        notifyCustomer: true,
        trackingInfo: tracking_info.presence,
        lineItemsByFulfillmentOrder: line_items_payload
      }.compact
    }

    response = shopify_client.query(query: mutation, variables: variables)

    # Check for errors
    user_errors = response.body.dig("data", "fulfillmentCreate", "userErrors") || []

    if user_errors.any?
      error_messages = user_errors.map { |e| "#{e['field']}: #{e['message']}" }.join(", ")
      Rails.logger.error "Shopify fulfillment creation errors: #{error_messages}"
      return { success: false, error: error_messages }
    end

    shopify_fulfillment = response.body.dig("data", "fulfillmentCreate", "fulfillment")

    if shopify_fulfillment
      shopify_fulfillment_id = shopify_fulfillment["id"]
      Rails.logger.info "Successfully created Shopify fulfillment: #{shopify_fulfillment_id}"
      { success: true, shopify_fulfillment_id: shopify_fulfillment_id }
    else
      error = response.body.dig("errors") || "Unknown error"
      Rails.logger.error "Failed to create Shopify fulfillment: #{error}"
      { success: false, error: error.to_s }
    end
  end

  def shopify_client
    @shopify_client ||= ShopifyAPI::Clients::Graphql::Admin.new(
      session: shopify_session
    )
  end

  def shopify_session
    @shopify_session ||= ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  def log_success_activity(shopify_fulfillment_id)
    OrderActivityService.new(order: order).log_fulfillment_synced_to_shopify(
      fulfillment: fulfillment,
      shopify_fulfillment_id: shopify_fulfillment_id
    )
  end

  def log_error_activity(error_message)
    OrderActivityService.new(order: order).log_fulfillment_sync_error(
      fulfillment: fulfillment,
      error_message: error_message
    )
  end

  def build_success_description
    parts = [ "Fulfillment synced to #{store.name}" ]

    if fulfillment.tracking_number.present?
      parts << "with tracking #{fulfillment.tracking_number}"
    end

    parts << "(#{fulfillment.item_count} #{'item'.pluralize(fulfillment.item_count)})"

    parts.join(" ")
  end
end
