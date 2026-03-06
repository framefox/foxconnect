namespace :report do
  desc "Report how many times a frame SKU was ordered in fulfilled orders. Usage: rake report:sku_frequency DOMAIN=ledendesign.myshopify.com SKU=HBFX-RAG-UNFRAMED-PRINT-841-x-594mm"
  task sku_frequency: :environment do
    domain = ENV.fetch("DOMAIN") { abort "Usage: rake report:sku_frequency DOMAIN=example.myshopify.com SKU=FRAME-SKU-CODE" }
    sku = ENV.fetch("SKU") { abort "Usage: rake report:sku_frequency DOMAIN=example.myshopify.com SKU=FRAME-SKU-CODE" }

    store = Store.find_by(shopify_domain: domain)
    abort "Store not found for domain: #{domain}" unless store

    fulfilled_orders = store.orders.where(aasm_state: "fulfilled")

    puts "Store: #{store.name} (#{domain})"
    puts "Total fulfilled orders: #{fulfilled_orders.count}"
    puts "Searching for frame SKU: #{sku}"
    puts "-" * 60

    matching_items = OrderItem
      .joins(:order)
      .where(orders: { id: fulfilled_orders.select(:id) })
      .where(deleted_at: nil)
      .where(
        "order_items.id IN (?) OR order_items.variant_mapping_id IN (?)",
        VariantMapping.where(frame_sku_code: sku).where.not(order_item_id: nil).select(:order_item_id),
        VariantMapping.where(frame_sku_code: sku).select(:id)
      )
      .includes(:order)

    if matching_items.none?
      puts "No fulfilled orders found containing SKU: #{sku}"
      next
    end

    total_quantity = 0

    matching_items.order("orders.created_at ASC").each do |item|
      order = item.order
      total_quantity += item.quantity
      puts "#{order.created_at.to_date}  Order #{order.shopify_remote_order_name || order.external_number}  qty: #{item.quantity}  item: #{item.display_name}"
    end

    puts "-" * 60
    puts "Orders containing this SKU: #{matching_items.count}"
    puts "Total units ordered: #{total_quantity}"
  end
end
