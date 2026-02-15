namespace :fulfillments do
  desc "Fix orders incorrectly showing as 'partially fulfilled' due to missing shopify_remote_line_item_id"
  task fix_partially_fulfilled: :environment do
    puts "Finding orders incorrectly showing as 'partially fulfilled'..."

    # Find orders that:
    # 1. Are in_production state
    # 2. Have fulfillments
    # 3. Are showing as partially_fulfilled
    # Use select_all to get order IDs first to avoid DISTINCT issues with JSON columns
    order_ids = Order.where(aasm_state: "in_production")
                     .joins(:fulfillments)
                     .select("orders.id")
                     .distinct
                     .pluck(:id)

    affected_orders = Order.where(id: order_ids).select do |order|
      order.fulfillments.any? && order.partially_fulfilled?
    end

    if affected_orders.empty?
      puts "No affected orders found."
      exit 0
    end

    puts "Found #{affected_orders.count} affected orders"
    puts

    fixed_count = 0
    error_count = 0

    affected_orders.each do |order|
      puts "Processing Order ##{order.id} (UID: #{order.uid}, #{order.display_name})..."

      # Get the order items that need fixing
      items_to_fix = order.active_order_items.where(shopify_remote_line_item_id: nil)
      puts "  - #{items_to_fix.count} order items missing shopify_remote_line_item_id"

      # Try to match using variant_mappings
      items_to_fix.each do |item|
        # Get variant mappings for this item (new style)
        mappings = item.variant_mappings.any? ? item.variant_mappings : [item.variant_mapping].compact

        if mappings.empty?
          puts "  - Item #{item.id}: No variant mappings found"
          next
        end

        # For each mapping, check if we can find a matching fulfillment line item
        # by looking at the fulfillment data
        mappings.each do |mapping|
          puts "  - Item #{item.id}: Checking variant_mapping #{mapping.id}"

          # Look for existing fulfillment line items that might be orphaned
          # or need to be created
          order.fulfillments.each do |fulfillment|
            # Check if this item already has a fulfillment line item
            existing_fli = fulfillment.fulfillment_line_items.find_by(order_item_id: item.id)

            unless existing_fli
              # Create fulfillment line item for this order item
              puts "  - Creating FulfillmentLineItem for item #{item.id} in fulfillment #{fulfillment.id}"
              begin
                FulfillmentLineItem.create!(
                  fulfillment: fulfillment,
                  order_item: item,
                  quantity: item.quantity
                )
                puts "    ✓ Created FulfillmentLineItem"
              rescue => e
                puts "    ✗ Error creating FulfillmentLineItem: #{e.message}"
              end
            end
          end
        end
      end

      # Check if order is now fully fulfilled and update state
      order.reload
      if order.fully_fulfilled? && order.may_fulfill?
        order.fulfill!
        puts "  ✓ Order transitioned to fulfilled state"
      end

      new_status = order.fulfillment_status
      puts "  - New fulfillment_status: #{new_status}"

      if new_status == :fulfilled
        fixed_count += 1
        puts "  ✓ Order fixed!"
      else
        puts "  - Order still shows as #{new_status}"
      end

      puts
    rescue => e
      puts "  ✗ Error processing order #{order.id}: #{e.message}"
      puts e.backtrace.first(5).join("\n")
      error_count += 1
    end

    puts "=" * 60
    puts "Summary:"
    puts "  - Total affected orders: #{affected_orders.count}"
    puts "  - Fixed: #{fixed_count}"
    puts "  - Errors: #{error_count}"
    puts "  - Still affected: #{affected_orders.count - fixed_count - error_count}"
  end

  desc "Diagnose a specific order's fulfillment status"
  task :diagnose, [:order_uid] => :environment do |t, args|
    unless args[:order_uid]
      puts "Usage: rails fulfillments:diagnose[ORDER_UID]"
      puts "Example: rails fulfillments:diagnose[96101496]"
      exit 1
    end

    order = Order.find_by(uid: args[:order_uid])

    unless order
      puts "Order not found with UID: #{args[:order_uid]}"
      exit 1
    end

    puts "=" * 60
    puts "Order Diagnosis: #{order.display_name} (UID: #{order.uid})"
    puts "=" * 60
    puts
    puts "Basic Info:"
    puts "  - ID: #{order.id}"
    puts "  - State: #{order.aasm_state}"
    puts "  - Fulfillment Status: #{order.fulfillment_status}"
    puts "  - Display State: #{order.display_state}"
    puts "  - shopify_remote_order_id: #{order.shopify_remote_order_id || 'nil'}"
    puts

    puts "Order Items (#{order.order_items.count} total, #{order.active_order_items.count} active):"
    order.active_order_items.each do |item|
      puts "  Item ##{item.id}: #{item.display_name}"
      puts "    - quantity: #{item.quantity}"
      puts "    - is_custom: #{item.is_custom?}"
      puts "    - fulfillable?: #{item.fulfillable?}"
      puts "    - variant_mapping_id (deprecated): #{item.variant_mapping_id || 'nil'}"
      puts "    - variant_mappings.count: #{item.variant_mappings.count}"
      puts "    - shopify_remote_line_item_id: #{item.shopify_remote_line_item_id || 'nil'}"
      puts "    - fulfilled_quantity: #{item.fulfilled_quantity}"
      puts "    - fully_fulfilled?: #{item.fully_fulfilled?}"

      if item.variant_mappings.any?
        puts "    - Variant Mappings (new style):"
        item.variant_mappings.each do |vm|
          puts "      - VM ##{vm.id}: order_item_id=#{vm.order_item_id}"
        end
      elsif item.variant_mapping
        puts "    - Variant Mapping (old style): VM ##{item.variant_mapping.id}"
      end
      puts
    end

    puts "Fulfillable Items: #{order.fulfillable_items.count}"
    order.fulfillable_items.each do |item|
      puts "  - Item ##{item.id}: fully_fulfilled?=#{item.fully_fulfilled?}"
    end
    puts

    puts "Fulfillments (#{order.fulfillments.count}):"
    order.fulfillments.each do |f|
      puts "  Fulfillment ##{f.id}:"
      puts "    - status: #{f.status}"
      puts "    - shopify_fulfillment_id: #{f.shopify_fulfillment_id || 'nil'}"
      puts "    - fulfilled_at: #{f.fulfilled_at}"
      puts "    - Line Items (#{f.fulfillment_line_items.count}):"
      f.fulfillment_line_items.each do |fli|
        puts "      - FLI ##{fli.id}: order_item_id=#{fli.order_item_id}, quantity=#{fli.quantity}"
      end
    end
    puts

    puts "Analysis:"
    puts "  - Has fulfillments: #{order.fulfillments.any?}"
    puts "  - partially_fulfilled?: #{order.partially_fulfilled?}"
    puts "  - fully_fulfilled?: #{order.fully_fulfilled?}"

    # Check for the specific bug
    items_without_remote_id = order.active_order_items.where(shopify_remote_line_item_id: nil)
    if items_without_remote_id.any?
      puts
      puts "⚠️  POTENTIAL BUG DETECTED:"
      puts "   #{items_without_remote_id.count} order item(s) missing shopify_remote_line_item_id"
      puts "   This may be causing fulfillment matching to fail."
      puts
      puts "   Items affected:"
      items_without_remote_id.each do |item|
        puts "     - Item ##{item.id}: #{item.display_name}"
        if item.variant_mappings.any?
          puts "       (uses new bundle system with #{item.variant_mappings.count} variant_mappings)"
        end
      end
    end

    items_without_fli = order.fulfillable_items.select { |item| item.fulfillment_line_items.none? }
    if items_without_fli.any? && order.fulfillments.any?
      puts
      puts "⚠️  MISSING FULFILLMENT LINE ITEMS:"
      puts "   #{items_without_fli.count} fulfillable item(s) have no FulfillmentLineItem records"
      puts "   but the order has #{order.fulfillments.count} fulfillment(s)."
      puts
      puts "   Run 'rails fulfillments:fix_partially_fulfilled' to fix this."
    end
  end
end
