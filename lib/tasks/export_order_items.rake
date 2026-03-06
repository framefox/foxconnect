require "csv"

namespace :export do
  desc "Export fulfilled order items to CSV for a store. Usage: rake export:order_items DOMAIN=ledendesign.myshopify.com"
  task order_items: :environment do
    domain = ENV.fetch("DOMAIN") { abort "Usage: rake export:order_items DOMAIN=example.myshopify.com" }

    store = Store.find_by(shopify_domain: domain)
    abort "Store not found for domain: #{domain}" unless store

    orders = store.orders.where(aasm_state: "fulfilled").order(:created_at).includes(:order_items)
    items = orders.flat_map { |o| o.order_items.active.store_synced }

    puts "Store: #{store.name} (#{domain})"
    puts "Fulfilled orders: #{orders.count}"
    puts "Line items (excluding custom): #{items.count}"

    filename = "fulfilled_order_items_#{domain.split('.').first}_#{Date.today.iso8601}.csv"
    filepath = Rails.root.join("tmp", filename)

    CSV.open(filepath, "w") do |csv|
      csv << %w[order_date external_number shopify_order_name title sku variant_title price discount_amount tax_amount production_cost gross_margin_percentage]

      items.each do |item|
        csv << [
          item.order.created_at.to_date.iso8601,
          item.order.external_number,
          item.order.shopify_remote_order_name,
          item.title,
          item.sku,
          item.variant_title,
          item.price.to_f,
          item.discount_amount.to_f,
          item.tax_amount.to_f,
          item.production_cost.to_f,
          item.gross_margin_percentage
        ]
      end
    end

    puts "Exported to #{filepath}"
  end
end
