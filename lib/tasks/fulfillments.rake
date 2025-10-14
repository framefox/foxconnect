namespace :fulfillments do
  desc "Create a test fulfillment for an order"
  task :create_test, [ :order_id ] => :environment do |t, args|
    unless args[:order_id]
      puts "Usage: rails fulfillments:create_test[ORDER_ID]"
      puts "Example: rails fulfillments:create_test[123]"
      exit 1
    end

    order = Order.find(args[:order_id])
    puts "Creating test fulfillment for Order ##{order.id} (#{order.display_name})"
    puts "Order has #{order.active_order_items.count} items"

    # Build sample fulfillment data
    fulfillment_data = {
      "id" => SecureRandom.random_number(1_000_000_000),
      "order_id" => order.shopify_remote_order_id || order.external_id,
      "status" => "success",
      "created_at" => Time.current.iso8601,
      "tracking_company" => "New Zealand Post",
      "tracking_number" => "NZ#{SecureRandom.hex(8).upcase}",
      "tracking_url" => "https://track.nzpost.co.nz/track/NZ#{SecureRandom.hex(8).upcase}",
      "shipment_status" => "in_transit",
      "location_id" => "1",
      "origin_address" => {
        "name" => "Framefox HQ"
      },
      "line_items" => order.active_order_items.map do |item|
        {
          "id" => item.shopify_remote_line_item_id || item.external_line_id,
          "variant_id" => item.external_variant_id,
          "title" => item.title,
          "quantity" => item.quantity,
          "sku" => item.sku
        }
      end
    }

    puts "\nFulfillment data:"
    puts JSON.pretty_generate(fulfillment_data)

    # Create fulfillment
    service = InboundFulfillmentService.new(order: order, fulfillment_data: fulfillment_data)
    fulfillment = service.create_fulfillment

    if fulfillment
      puts "\n✓ Fulfillment created successfully!"
      puts "  ID: #{fulfillment.id}"
      puts "  Status: #{fulfillment.status}"
      puts "  Tracking: #{fulfillment.carrier_and_tracking}"
      puts "  Items fulfilled: #{fulfillment.item_count}"
      puts "\nOrder status: #{order.reload.aasm_state}"
      puts "Fulfillment status: #{order.fulfillment_status}"
    else
      puts "\n✗ Failed to create fulfillment"
      puts "Errors: #{service.errors.join(', ')}"
      exit 1
    end
  end

  desc "Create a partial test fulfillment for an order"
  task :create_partial, [ :order_id, :item_count ] => :environment do |t, args|
    unless args[:order_id]
      puts "Usage: rails fulfillments:create_partial[ORDER_ID,ITEM_COUNT]"
      puts "Example: rails fulfillments:create_partial[123,1]"
      exit 1
    end

    order = Order.find(args[:order_id])
    item_count = (args[:item_count] || 1).to_i

    puts "Creating partial fulfillment for Order ##{order.id}"
    puts "Fulfilling #{item_count} of #{order.active_order_items.count} items"

    items_to_fulfill = order.active_order_items.limit(item_count)

    fulfillment_data = {
      "id" => SecureRandom.random_number(1_000_000_000),
      "order_id" => order.shopify_remote_order_id || order.external_id,
      "status" => "success",
      "created_at" => Time.current.iso8601,
      "tracking_company" => "DHL Express",
      "tracking_number" => "DHL#{SecureRandom.hex(8).upcase}",
      "tracking_url" => "https://www.dhl.com/track/DHL#{SecureRandom.hex(8).upcase}",
      "origin_address" => {
        "name" => "Framefox HQ"
      },
      "line_items" => items_to_fulfill.map do |item|
        {
          "id" => item.shopify_remote_line_item_id || item.external_line_id,
          "quantity" => 1
        }
      end
    }

    service = InboundFulfillmentService.new(order: order, fulfillment_data: fulfillment_data)
    fulfillment = service.create_fulfillment

    if fulfillment
      puts "\n✓ Partial fulfillment created successfully!"
      puts "  Items fulfilled in this shipment: #{fulfillment.item_count}"
      puts "  Total fulfilled: #{order.reload.fulfilled_items_count}"
      puts "  Total unfulfilled: #{order.unfulfilled_items_count}"
      puts "  Order state: #{order.aasm_state}"
    else
      puts "\n✗ Failed to create fulfillment"
      puts "Errors: #{service.errors.join(', ')}"
    end
  end

  desc "List fulfillments for an order"
  task :list, [ :order_id ] => :environment do |t, args|
    unless args[:order_id]
      puts "Usage: rails fulfillments:list[ORDER_ID]"
      exit 1
    end

    order = Order.find(args[:order_id])
    puts "Order ##{order.id} (#{order.display_name})"
    puts "State: #{order.aasm_state}"
    puts "Fulfillment status: #{order.fulfillment_status}"
    puts "\nFulfillments (#{order.fulfillments.count}):"

    order.fulfillments.recent.each do |f|
      puts "\n  Fulfillment ##{f.id}"
      puts "    Status: #{f.status}"
      puts "    Fulfilled at: #{f.fulfilled_at}"
      puts "    Tracking: #{f.carrier_and_tracking}" if f.tracking_info_present?
      puts "    Items: #{f.item_count}"
      f.fulfillment_line_items.each do |fli|
        puts "      - #{fli.order_item.display_name} (qty: #{fli.quantity})"
      end
    end

    unfulfilled = order.active_order_items.select { |i| i.unfulfilled_quantity > 0 }
    if unfulfilled.any?
      puts "\nUnfulfilled items:"
      unfulfilled.each do |item|
        puts "  - #{item.display_name} (qty: #{item.unfulfilled_quantity})"
      end
    end
  end
end
