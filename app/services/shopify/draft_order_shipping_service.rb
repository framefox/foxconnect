module Shopify
  class DraftOrderShippingService
    attr_reader :order, :draft_order_gid, :graphql_client

    def initialize(order:, draft_order_gid:)
      @order = order
      @draft_order_gid = draft_order_gid
      @graphql_client = Shopify::GraphqlClient.new(order: order)
    end

    # Orchestrates the shipping rate application process
    def apply_shipping
      Rails.logger.info "=" * 80
      Rails.logger.info "SHIPPING RATE APPLICATION START"
      Rails.logger.info "Draft Order: #{draft_order_gid}"
      Rails.logger.info "Order: #{order.display_name} (ID: #{order.id})"
      Rails.logger.info "=" * 80

      # Step 1: Get the draft order details
      Rails.logger.info "Step 1: Fetching draft order details from Shopify..."
      draft_order_data = fetch_draft_order

      unless draft_order_data
        Rails.logger.error "❌ Failed to fetch draft order data - aborting shipping rate application"
        return false
      end

      Rails.logger.info "✓ Draft order data fetched successfully"

      # Step 2: Fetch available shipping rates
      Rails.logger.info "Step 2: Fetching available shipping rates..."
      available_rates = fetch_available_rates(draft_order_data)

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
      apply_result = apply_rate(selected_rate)

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
      Rails.logger.error "❌ EXCEPTION in apply_shipping"
      Rails.logger.error "Error: #{e.class} - #{e.message}"
      Rails.logger.error "Backtrace:"
      Rails.logger.error e.backtrace.first(10).join("\n")
      Rails.logger.error "=" * 80
      false
    end

    private

    def fetch_draft_order
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

      response = graphql_client.query(query, variables)
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

    def fetch_available_rates(draft_order_data)
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

      response = graphql_client.query(query, variables)
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

    def apply_rate(shipping_rate)
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

      response = graphql_client.query(mutation, variables)
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
  end
end
