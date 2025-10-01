require "http"

class OrderProductionService
  attr_reader :order

  def initialize(order:)
    @order = order
  end

  def call
    Rails.logger.info "Sending order #{order.display_name} to production"

    return failure("No items with variant mappings") unless valid_items.any?

    payload = build_payload
    send_to_api(payload)
  rescue => e
    Rails.logger.error "Production service error: #{e.message}"
    failure("Unexpected error: #{e.message}")
  end

  private

  def valid_items
    @valid_items ||= order.active_order_items.joins(:variant_mapping)
  end

  def build_payload
    draft_order_items = valid_items.map do |item|
      mapping = item.variant_mapping
      {
        variant_mapping_id: mapping.id,
        image_id: mapping.image_id,
        frame_sku_id: mapping.frame_sku_id,
        cx: mapping.cx,
        cy: mapping.cy,
        cw: mapping.cw,
        ch: mapping.ch
      }
    end

    { draft_order: { draft_order_items: draft_order_items } }
  end

  def send_to_api(payload)
    response = HTTP
      .timeout(connect: 10, read: 30)
      .headers("Content-Type" => "application/json", "Accept" => "application/json")
      .post(api_url, json: payload)

    handle_response(response)
  rescue HTTP::TimeoutError
    failure("Request timed out")
  rescue HTTP::ConnectionError
    failure("Connection error")
  end

  def handle_response(response)
    case response.status
    when 200..202
      data = JSON.parse(response.body.to_s)
      save_shopify_id(data)
      success(data)
    when 400..499
      failure("Client error (#{response.status})")
    when 500..599
      failure("Server error (#{response.status})")
    else
      failure("Unexpected response (#{response.status})")
    end
  rescue JSON::ParserError
    failure("Invalid response format")
  end

  def save_shopify_id(data)
    gid = data.dig("shopify_draft_order", "id")
    return unless gid

    shopify_id = gid.split("/").last
    order.update(shopify_remote_draft_order_id: shopify_id)
    Rails.logger.info "Saved Shopify draft order ID: #{shopify_id}"

    # Complete the draft order
    complete_draft_order(gid)
  end

  def api_url
    ENV["PRODUCTION_API_URL"] || "http://dev.framefox.co.nz:3001/api/draft_orders"
  end

  def success(data)
    { success: true, response: data }
  end

  def failure(message)
    Rails.logger.error "Production API error: #{message}"
    { success: false, error: message }
  end

  def complete_draft_order(draft_order_gid)
    Rails.logger.info "Completing Shopify draft order: #{draft_order_gid}"

    # First update with customer and shipping details
    update_result = update_draft_order_customer(draft_order_gid)
    return unless update_result

    # Then complete the draft order
    complete_result = finalize_draft_order(draft_order_gid)
    Rails.logger.info "Draft order completion result: #{complete_result ? 'success' : 'failed'}"
  end

  def update_draft_order_customer(draft_order_gid)
    mutation = <<~GRAPHQL
      mutation draftOrderUpdate($id: ID!, $input: DraftOrderInput!) {
        draftOrderUpdate(id: $id, input: $input) {
          draftOrder { id name }
          userErrors { field message }
        }
      }
    GRAPHQL

    variables = {
      id: draft_order_gid,
      input: build_customer_input
    }

    response = shopify_graphql_request(mutation, variables)
    return false unless response

    result = response.body

    if result&.dig("data", "draftOrderUpdate", "userErrors")&.any?
      errors = result["data"]["draftOrderUpdate"]["userErrors"]
      Rails.logger.error "Draft order update errors: #{errors}"
      return false
    end

    Rails.logger.info "Successfully updated draft order with customer details"
    true
  rescue => e
    Rails.logger.error "Error updating draft order customer: #{e.message}"
    false
  end

  def finalize_draft_order(draft_order_gid)
    mutation = <<~GRAPHQL
      mutation draftOrderComplete($id: ID!, $paymentPending: Boolean) {
        draftOrderComplete(id: $id, paymentPending: $paymentPending) {
          draftOrder {
            order { id name totalPrice }
          }
          userErrors { field message }
        }
      }
    GRAPHQL

    variables = {
      id: draft_order_gid,
      paymentPending: false
    }

    response = shopify_graphql_request(mutation, variables)
    return false unless response

    result = response.body

    if result&.dig("data", "draftOrderComplete", "userErrors")&.any?
      errors = result["data"]["draftOrderComplete"]["userErrors"]
      Rails.logger.error "Draft order completion errors: #{errors}"
      return false
    end

    # Log and save the created order
    if order_data = result&.dig("data", "draftOrderComplete", "draftOrder", "order")
      shopify_order_gid = order_data["id"]
      shopify_order_id = shopify_order_gid.split("/").last

      order.update(
        shopify_remote_order_id: shopify_order_id,
        shopify_remote_order_name: order_data["name"]
      )
      Rails.logger.info "Created Shopify order: #{order_data['name']} (ID: #{shopify_order_id})"
    end

    true
  rescue => e
    Rails.logger.error "Error completing draft order: #{e.message}"
    false
  end

  def build_customer_input
    input = {}

    # Add shipping address if available
    if order.shipping_address
      addr = order.shipping_address
      shipping_address = {
        firstName: addr.first_name,
        lastName: addr.last_name,
        company: addr.company,
        address1: addr.address1,
        address2: addr.address2,
        city: addr.city,
        province: addr.province,
        zip: addr.postal_code,
        country: addr.country,
        phone: addr.phone || order.customer_phone
      }.compact

      input[:shippingAddress] = shipping_address
      input[:billingAddress] = shipping_address
    end

    # Add customer info from order
    if order.customer_email.present?
      input[:email] = order.customer_email
    end

    input
  end

  def shopify_graphql_request(query, variables)
    # Use internal Shopify credentials for production system integration
    session = ShopifyAPI::Auth::Session.new(
      shop: ENV["internal_shopify_domain_nz"],
      access_token: ENV["internal_shopify_access_token_nz"]
    )

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
    client.query(query: query, variables: variables)
  rescue => e
    Rails.logger.error "Shopify GraphQL request failed: #{e.message}"
    Rails.logger.error "Shop: #{ENV['internal_shopify_domain_nz']}"
    Rails.logger.error "Access token present: #{ENV['internal_shopify_access_token_nz'].present?}"
    nil
  end
end
