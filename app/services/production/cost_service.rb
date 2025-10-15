module Production
  class CostService
    attr_reader :order

    def initialize(order:)
      @order = order
    end

    # Saves draft order metadata from production API response
    def save_draft_order_metadata(api_response)
      # Log the full API response for debugging
      Rails.logger.info "=" * 80
      Rails.logger.info "Production API Response:"
      Rails.logger.info JSON.pretty_generate(api_response)
      Rails.logger.info "=" * 80

      # Handle new API response format: { draft_order, shopify_data, target_dispatch_date, errors }
      # Also support legacy format: { shopify_draft_order }
      gid = api_response.dig("shopify_data", "id") || api_response.dig("shopify_draft_order", "id")
      return nil unless gid

      shopify_id = gid.split("/").last

      # Prepare update attributes
      update_attrs = {
        shopify_remote_draft_order_id: shopify_id,
        in_production_at: Time.current
      }

      # Add target_dispatch_date if present in response (top-level in new format)
      if target_dispatch_date = api_response["target_dispatch_date"]
        # Handle both string and Date formats
        parsed_date = target_dispatch_date.is_a?(String) ? Date.parse(target_dispatch_date) : target_dispatch_date
        update_attrs[:target_dispatch_date] = parsed_date
        Rails.logger.info "Found target_dispatch_date in API response: #{target_dispatch_date}"
      else
        Rails.logger.warn "No target_dispatch_date in API response"
      end

      order.update(update_attrs)
      Rails.logger.info "Saved Shopify draft order ID: #{shopify_id}"
      Rails.logger.info "Set in_production_at: #{Time.current}"
      Rails.logger.info "Set target_dispatch_date: #{update_attrs[:target_dispatch_date]}" if update_attrs[:target_dispatch_date]

      # Log production activity
      OrderActivityService.new(order: order).log_production_sent(
        production_result: { success: true, shopify_id: shopify_id, target_dispatch_date: update_attrs[:target_dispatch_date] }
      )

      gid
    end

    # Saves production costs from completed Shopify order
    def save_order_costs(shopify_order_data)
      shopify_order_gid = shopify_order_data["id"]
      shopify_order_id = shopify_order_gid.split("/").last

      # Extract production costs from Shopify order
      production_subtotal = extract_money_amount(shopify_order_data["subtotalPriceSet"])
      production_shipping = extract_money_amount(shopify_order_data["totalShippingPriceSet"])
      production_total = extract_money_amount(shopify_order_data["totalPriceSet"])

      order.update(
        shopify_remote_order_id: shopify_order_id,
        shopify_remote_order_name: shopify_order_data["name"],
        production_subtotal_cents: (production_subtotal * 100).to_i,
        production_shipping_cents: (production_shipping * 100).to_i,
        production_total_cents: (production_total * 100).to_i
      )
      Rails.logger.info "Created Shopify order: #{shopify_order_data['name']} (ID: #{shopify_order_id})"
      Rails.logger.info "Order created with PAYMENT PENDING - manual capture will be required"
      Rails.logger.info "Saved production costs - Subtotal: #{production_subtotal}, Shipping: #{production_shipping}, Total: #{production_total}"
    end

    # Saves line item production costs
    def save_line_item_costs(line_items_data)
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
        production_cost = extract_money_amount(line_item["originalUnitPriceSet"])

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

    private

    def extract_money_amount(price_set)
      amount_str = price_set&.dig("shopMoney", "amount")
      amount_str ? BigDecimal(amount_str) : BigDecimal(0)
    end
  end
end
