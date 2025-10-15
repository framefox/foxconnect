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
      error_message = extract_error_message(response)
      failure("Client error (#{response.status}): #{error_message}")
    when 500..599
      error_message = extract_error_message(response)
      failure("Server error (#{response.status}): #{error_message}")
    else
      error_message = extract_error_message(response)
      failure("Unexpected response (#{response.status}): #{error_message}")
    end
  rescue JSON::ParserError
    failure("Invalid response format")
  end

  def save_shopify_id(data)
    gid = data.dig("shopify_draft_order", "id")
    return unless gid

    shopify_id = gid.split("/").last

    # Prepare update attributes
    update_attrs = {
      shopify_remote_draft_order_id: shopify_id,
      in_production_at: Time.current
    }

    # Add target_dispatch_date if present in response
    if target_dispatch_date = data["target_dispatch_date"]
      update_attrs[:target_dispatch_date] = Date.parse(target_dispatch_date)
    end

    order.update(update_attrs)
    Rails.logger.info "Saved Shopify draft order ID: #{shopify_id}"
    Rails.logger.info "Set in_production_at: #{Time.current}"
    Rails.logger.info "Set target_dispatch_date: #{target_dispatch_date}" if target_dispatch_date

    # Log production activity
    OrderActivityService.new(order: order).log_production_sent(
      production_result: { success: true, shopify_id: shopify_id, target_dispatch_date: target_dispatch_date }
    )

    # Complete the draft order
    complete_draft_order(gid)
  end

  def api_url
    return ENV["PRODUCTION_API_URL"] || "http://dev.framefox.co.nz:3001/api/draft_orders" unless order.country_config
    "#{order.country_config['api_url']}#{order.country_config['api_base_path']}/draft_orders"
  end

  def success(data)
    { success: true, response: data }
  end

  def failure(message)
    Rails.logger.error "Production API error: #{message}"
    { success: false, error: message }
  end

  def extract_error_message(response)
    return "Unknown error" if response.body.to_s.empty?

    begin
      error_data = JSON.parse(response.body.to_s)

      # Try different common error message formats
      if error_data.is_a?(Hash)
        # Check for common error message keys
        error_message = error_data["error"] ||
                       error_data["message"] ||
                       error_data["errors"]&.join(", ") ||
                       error_data.dig("errors", "message") ||
                       error_data.dig("error", "message")

        return error_message if error_message.present?
      end

      # If no structured error found, return the raw body (truncated if too long)
      raw_body = response.body.to_s
      raw_body.length > 200 ? "#{raw_body[0..200]}..." : raw_body
    rescue JSON::ParserError
      # If response isn't JSON, return raw body (truncated if too long)
      raw_body = response.body.to_s
      raw_body.length > 200 ? "#{raw_body[0..200]}..." : raw_body
    end
  end

  def extract_money_amount_from_set(price_set)
    amount_str = price_set&.dig("shopMoney", "amount")
    amount_str ? BigDecimal(amount_str) : BigDecimal(0)
  end

  def complete_draft_order(draft_order_gid)
    Rails.logger.info "Completing Shopify draft order: #{draft_order_gid}"

    # First update with customer and shipping details
    update_result = update_draft_order_customer(draft_order_gid)
    return unless update_result

    # Apply shipping rates
    apply_shipping_rate(draft_order_gid)

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

    Rails.logger.info "Updating draft order with variables:"
    Rails.logger.info JSON.pretty_generate(variables)

    response = shopify_graphql_request(mutation, variables)
    return false unless response

    result = response.body

    if result&.dig("data", "draftOrderUpdate", "userErrors")&.any?
      errors = result["data"]["draftOrderUpdate"]["userErrors"]
      Rails.logger.error "Draft order update errors: #{errors.inspect}"
      return false
    end

    Rails.logger.info "Successfully updated draft order with customer details"
    true
  rescue => e
    Rails.logger.error "Error updating draft order customer: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    false
  end

  def apply_shipping_rate(draft_order_gid)
    Rails.logger.info "=" * 80
    Rails.logger.info "SHIPPING RATE APPLICATION START"
    Rails.logger.info "Draft Order: #{draft_order_gid}"
    Rails.logger.info "Order: #{order.display_name} (ID: #{order.id})"
    Rails.logger.info "=" * 80

    # Step 1: Get the draft order details
    Rails.logger.info "Step 1: Fetching draft order details from Shopify..."
    draft_order_data = fetch_draft_order_for_shipping(draft_order_gid)

    unless draft_order_data
      Rails.logger.error "❌ Failed to fetch draft order data - aborting shipping rate application"
      return false
    end

    Rails.logger.info "✓ Draft order data fetched successfully"

    # Step 2: Fetch available shipping rates
    Rails.logger.info "Step 2: Fetching available shipping rates..."
    available_rates = fetch_available_shipping_rates(draft_order_data)

    if available_rates.nil? || available_rates.empty?
      Rails.logger.warn "❌ No shipping rates available for draft order #{draft_order_gid}"
      Rails.logger.warn "This could mean:"
      Rails.logger.warn "  - No shipping zones configured for destination"
      Rails.logger.warn "  - API version doesn't support draftOrderAvailableDeliveryOptions"
      Rails.logger.warn "  - Products missing weight/dimensions"
      return false
    end

    Rails.logger.info "✓ Found #{available_rates.length} shipping rate(s)"

    # Step 3: Select the first available rate (typically the default/cheapest)
    selected_rate = available_rates.first
    Rails.logger.info "Step 3: Selecting shipping rate..."
    Rails.logger.info "✓ Selected: #{selected_rate['title']} - #{selected_rate.dig('price', 'amount')} #{selected_rate.dig('price', 'currencyCode')}"

    # Step 4: Apply the selected rate
    Rails.logger.info "Step 4: Applying shipping rate to draft order..."
    apply_result = update_draft_order_shipping(draft_order_gid, selected_rate)

    if apply_result
      Rails.logger.info "✅ Successfully applied shipping rate to draft order"
      Rails.logger.info "=" * 80
    else
      Rails.logger.error "❌ Failed to apply shipping rate"
      Rails.logger.warn "Continuing with order completion anyway"
      Rails.logger.info "=" * 80
    end

    apply_result
  rescue => e
    Rails.logger.error "=" * 80
    Rails.logger.error "❌ EXCEPTION in apply_shipping_rate"
    Rails.logger.error "Error: #{e.class} - #{e.message}"
    Rails.logger.error "Backtrace:"
    Rails.logger.error e.backtrace.first(10).join("\n")
    Rails.logger.error "=" * 80
    false
  end

  def fetch_draft_order_for_shipping(draft_order_gid)
    Rails.logger.info "  → Fetching draft order from Shopify..."

    query = <<~GRAPHQL
      query getDraftOrder($id: ID!) {
        draftOrder(id: $id) {
          id
          status
          lineItems(first: 50) {
            edges {
              node {
                id
                title
                quantity
                originalUnitPriceSet {
                  shopMoney {
                    amount
                  }
                }
                requiresShipping
                variant {
                  id
                }
                weight {
                  unit
                  value
                }
              }
            }
          }
          shippingAddress {
            address1
            address2
            city
            province
            country
            zip
          }
        }
      }
    GRAPHQL

    variables = { id: draft_order_gid }

    response = shopify_graphql_request(query, variables)
    unless response
      Rails.logger.error "  ❌ No response from shopify_graphql_request"
      return nil
    end

    result = response.body
    draft_order = result&.dig("data", "draftOrder")

    if result["errors"]
      Rails.logger.error "  ❌ GraphQL errors fetching draft order:"
      result["errors"].each { |e| Rails.logger.error "     - #{e['message']}" }
      return nil
    end

    if draft_order
      # Check if draft order is already completed
      if draft_order["status"] == "COMPLETED"
        Rails.logger.warn "  ⚠️  Draft order is already COMPLETED - cannot apply shipping rates"
        return nil
      end

      line_item_count = draft_order.dig("lineItems", "edges")&.length || 0
      has_shipping_addr = draft_order["shippingAddress"].present?

      Rails.logger.info "  ✓ Draft order fetched: status=#{draft_order['status']}, line_items=#{line_item_count}, has_address=#{has_shipping_addr}"

      unless has_shipping_addr
        Rails.logger.error "  ❌ Draft order has NO shipping address - cannot calculate rates"
        return nil
      end

      draft_order
    else
      Rails.logger.error "  ❌ Draft order is null in response"
      Rails.logger.error "  Response: #{result.inspect[0..500]}"
      nil
    end
  rescue => e
    Rails.logger.error "  ❌ Exception fetching draft order: #{e.class} - #{e.message}"
    Rails.logger.error "  #{e.backtrace.first(3).join("\n  ")}"
    nil
  end

  def fetch_available_shipping_rates(draft_order_data)
    Rails.logger.info "  → Building shipping rate query input..."

    # Build the input from the draft order data
    line_items = draft_order_data.dig("lineItems", "edges")&.map do |edge|
      node = edge["node"]
      {
        variantId: node.dig("variant", "id"),
        quantity: node["quantity"],
        requiresShipping: node["requiresShipping"]
      }.compact
    end || []

    Rails.logger.info "  → #{line_items.length} line items with variants"

    shipping_address = draft_order_data["shippingAddress"]

    unless shipping_address
      Rails.logger.error "  ❌ No shipping address on draft order"
      return nil
    end

    Rails.logger.info "  → Shipping to: #{shipping_address['city']}, #{shipping_address['country']}"

    query = <<~GRAPHQL
      query draftOrderAvailableDeliveryOptions($input: DraftOrderAvailableDeliveryOptionsInput!) {
        draftOrderAvailableDeliveryOptions(input: $input) {
          availableShippingRates {
            handle
            title
            price {
              amount
              currencyCode
            }
          }
        }
      }
    GRAPHQL

    variables = {
      input: {
        lineItems: line_items,
        shippingAddress: {
          address1: shipping_address["address1"],
          address2: shipping_address["address2"],
          city: shipping_address["city"],
          province: shipping_address["province"],
          country: shipping_address["country"],
          zip: shipping_address["zip"]
        }.compact
      }
    }

    Rails.logger.info "  → Querying Shopify for available shipping rates..."
    Rails.logger.debug "  Query input: #{JSON.pretty_generate(variables)}"

    response = shopify_graphql_request(query, variables)
    unless response
      Rails.logger.error "  ❌ No response from shopify_graphql_request"
      return nil
    end

    result = response.body

    if result["errors"]
      Rails.logger.error "  ❌ GraphQL errors fetching shipping rates:"
      result["errors"].each do |error|
        Rails.logger.error "     - #{error['message']}"
      end
      Rails.logger.error "  This usually means the API version doesn't support draftOrderAvailableDeliveryOptions"
      return nil
    end

    rates = result&.dig("data", "draftOrderAvailableDeliveryOptions", "availableShippingRates")

    if rates && rates.any?
      Rails.logger.info "  ✓ Shopify returned #{rates.length} shipping rate(s):"
      rates.each_with_index do |rate, i|
        Rails.logger.info "     #{i+1}. #{rate['title']}: #{rate.dig('price', 'amount')} #{rate.dig('price', 'currencyCode')}"
      end
      rates
    else
      Rails.logger.warn "  ⚠️  Shopify returned 0 shipping rates"
      Rails.logger.warn "  Response data section: #{result['data'].inspect[0..300]}"
      nil
    end
  rescue => e
    Rails.logger.error "  ❌ Exception fetching shipping rates: #{e.class} - #{e.message}"
    Rails.logger.error "  #{e.backtrace.first(3).join("\n  ")}"
    nil
  end

  def update_draft_order_shipping(draft_order_gid, shipping_rate)
    Rails.logger.info "  → Applying shipping line via draftOrderUpdate mutation..."

    mutation = <<~GRAPHQL
      mutation draftOrderUpdate($id: ID!, $input: DraftOrderInput!) {
        draftOrderUpdate(id: $id, input: $input) {
          draftOrder {
            id
            shippingLine {
              title
              originalPriceSet {
                shopMoney {
                  amount
                  currencyCode
                }
              }
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL

    variables = {
      id: draft_order_gid,
      input: {
        shippingLine: {
          title: shipping_rate["title"],
          price: shipping_rate.dig("price", "amount")
        }
      }
    }

    Rails.logger.info "  → Mutation variables:"
    Rails.logger.info "     Title: #{shipping_rate['title']}"
    Rails.logger.info "     Price: #{shipping_rate.dig('price', 'amount')}"
    Rails.logger.debug "  #{JSON.pretty_generate(variables)}"

    response = shopify_graphql_request(mutation, variables)
    unless response
      Rails.logger.error "  ❌ No response from shopify_graphql_request"
      return false
    end

    result = response.body

    if result["errors"]
      Rails.logger.error "  ❌ GraphQL errors applying shipping:"
      result["errors"].each { |e| Rails.logger.error "     - #{e['message']}" }
      return false
    end

    if result&.dig("data", "draftOrderUpdate", "userErrors")&.any?
      errors = result["data"]["draftOrderUpdate"]["userErrors"]
      Rails.logger.error "  ❌ User errors applying shipping:"
      errors.each { |e| Rails.logger.error "     - #{e['field']}: #{e['message']}" }
      return false
    end

    shipping_line = result&.dig("data", "draftOrderUpdate", "draftOrder", "shippingLine")
    if shipping_line
      amount = shipping_line.dig("originalPriceSet", "shopMoney", "amount")
      currency = shipping_line.dig("originalPriceSet", "shopMoney", "currencyCode")
      Rails.logger.info "  ✓ Shipping line confirmed on draft order: #{shipping_line['title']} - #{amount} #{currency}"
    else
      Rails.logger.warn "  ⚠️  Shipping line not returned in mutation response"
    end

    true
  rescue => e
    Rails.logger.error "  ❌ Exception updating draft order shipping: #{e.class} - #{e.message}"
    Rails.logger.error "  #{e.backtrace.first(5).join("\n  ")}"
    false
  end

  def finalize_draft_order(draft_order_gid)
    mutation = <<~GRAPHQL
      mutation draftOrderComplete($id: ID!, $paymentPending: Boolean) {
        draftOrderComplete(id: $id, paymentPending: $paymentPending) {
          draftOrder {
            order {
              id
              name
              subtotalPriceSet {
                shopMoney {
                  amount
                  currencyCode
                }
              }
              totalShippingPriceSet {
                shopMoney {
                  amount
                  currencyCode
                }
              }
              totalPriceSet {
                shopMoney {
                  amount
                  currencyCode
                }
              }
              lineItems(first: 100) {
                edges {
                  node {
                    id
                    originalUnitPriceSet {
                      shopMoney {
                        amount
                        currencyCode
                      }
                    }
                    customAttributes {
                      key
                      value
                    }
                  }
                }
              }
            }
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

      # Extract production costs from Shopify order
      production_subtotal = extract_money_amount_from_set(order_data["subtotalPriceSet"])
      production_shipping = extract_money_amount_from_set(order_data["totalShippingPriceSet"])
      production_total = extract_money_amount_from_set(order_data["totalPriceSet"])

      order.update(
        shopify_remote_order_id: shopify_order_id,
        shopify_remote_order_name: order_data["name"],
        production_subtotal_cents: (production_subtotal * 100).to_i,
        production_shipping_cents: (production_shipping * 100).to_i,
        production_total_cents: (production_total * 100).to_i
      )
      Rails.logger.info "Created Shopify order: #{order_data['name']} (ID: #{shopify_order_id})"
      Rails.logger.info "Saved production costs - Subtotal: #{production_subtotal}, Shipping: #{production_shipping}, Total: #{production_total}"

      # Save line item IDs and production costs back to order items
      save_line_item_ids(order_data["lineItems"])
    end

    true
  rescue => e
    Rails.logger.error "Error completing draft order: #{e.message}"
    false
  end

  def build_customer_input
    input = {}

    # Add B2B purchasing entity (company information)
    # ALL orders in this service are B2B orders
    # Find the shopify_customer for this order's country
    user = order.store.user

    shopify_customer = user.shopify_customers.find_by(country_code: order.country_code)
    raise "User #{user.email} has no Shopify customer for country #{order.country_code}" unless shopify_customer

    if company = shopify_customer.company
      # Build full GIDs - IDs in database are stored without gid:// prefix
      company_gid = build_gid("Company", company.shopify_company_id)
      location_gid = build_gid("CompanyLocation", company.shopify_company_location_id)
      contact_gid = build_gid("CompanyContact", company.shopify_company_contact_id)

      input[:purchasingEntity] = {
        purchasingCompany: {
          companyId: company_gid,
          companyLocationId: location_gid,
          companyContactId: contact_gid
        }
      }

      Rails.logger.info "Adding B2B purchasingEntity for company: #{company.company_name}"
      Rails.logger.info "  Company GID: #{company_gid}"
      Rails.logger.info "  Location GID: #{location_gid}"
      Rails.logger.info "  Contact GID: #{contact_gid}"
    else
      Rails.logger.warn "Order #{order.display_name} has no company association - B2B order requires company!"
    end

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

    # Add pro-platform tag
    input[:tags] = [ "framefox-connect" ]

    input
  end

  def shopify_graphql_request(query, variables)
    # Use country-specific Shopify credentials from configuration
    config = order.country_config

    # Fallback to NZ environment variables if no config
    shop = config ? config["shopify_domain"] : ENV["remote_shopify_domain_nz"]
    token = config ? config["shopify_access_token"] : ENV["remote_shopify_access_token_nz"]

    session = ShopifyAPI::Auth::Session.new(
      shop: shop,
      access_token: token
    )

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
    client.query(query: query, variables: variables)
  rescue => e
    Rails.logger.error "Shopify GraphQL request failed: #{e.message}"
    Rails.logger.error "Shop: #{shop}"
    Rails.logger.error "Access token present: #{token.present?}"
    nil
  end

  def save_line_item_ids(line_items_data)
    return unless line_items_data

    Rails.logger.info "Matching and saving Shopify line item IDs..."

    # Get line items from GraphQL edges format
    line_items = line_items_data.dig("edges")&.map { |edge| edge["node"] } || []

    if line_items.empty?
      Rails.logger.warn "No line items returned from Shopify order"
      return
    end

    matched_count = 0
    unmatched_count = 0

    line_items.each do |line_item|
      # Extract the ConnectVariantMappingID from custom attributes
      custom_attrs = line_item["customAttributes"] || []
      mapping_id_attr = custom_attrs.find { |attr| attr["key"] == "ConnectVariantMappingID" }

      unless mapping_id_attr
        Rails.logger.warn "Line item #{line_item['id']} missing ConnectVariantMappingID"
        unmatched_count += 1
        next
      end

      variant_mapping_id = mapping_id_attr["value"].to_i

      # Find the matching order item by variant_mapping_id
      order_item = order.active_order_items.find_by(variant_mapping_id: variant_mapping_id)

      unless order_item
        Rails.logger.warn "No order item found for variant_mapping_id: #{variant_mapping_id}"
        unmatched_count += 1
        next
      end

      # Extract the numeric line item ID from the GID
      line_item_gid = line_item["id"]
      line_item_id = line_item_gid.split("/").last

      # Extract production cost from line item
      production_cost = extract_money_amount_from_set(line_item["originalUnitPriceSet"])

      # Save the line item ID and production cost
      order_item.update(
        shopify_remote_line_item_id: line_item_id,
        production_cost_cents: (production_cost * 100).to_i
      )
      Rails.logger.info "Saved line item ID #{line_item_id} and production cost #{production_cost} for order item #{order_item.id} (variant_mapping: #{variant_mapping_id})"
      matched_count += 1
    end

    Rails.logger.info "Line item matching complete: #{matched_count} matched, #{unmatched_count} unmatched"
  rescue => e
    Rails.logger.error "Error saving line item IDs: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
  end

  # Helper method to build Shopify GID format
  def build_gid(resource_type, id)
    # If ID already has gid:// prefix, return as-is
    return id if id.to_s.start_with?("gid://shopify/")

    # Otherwise, build the full GID
    "gid://shopify/#{resource_type}/#{id}"
  end
end
