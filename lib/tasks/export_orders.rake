require "csv"

namespace :export do
  desc "Export fulfilled orders to CSV"
  task orders: :environment do
    domain = ENV.fetch("DOMAIN") { abort "Usage: rake export:orders DOMAIN=example.myshopify.com" }

    store = Store.find_by(shopify_domain: domain)
    abort "Store not found for domain: #{domain}" unless store

    orders = store.orders.where(aasm_state: "fulfilled").order(:created_at)

    puts "Store: #{store.name} (#{domain})"
    puts "Fulfilled orders: #{orders.count}"

    filename = "fulfilled_orders_#{domain.split('.').first}_#{Date.today.iso8601}.csv"
    filepath = Rails.root.join("tmp", filename)

    CSV.open(filepath, "w") do |csv|
      csv << %w[
        order_date
        external_number
        shopify_order_name
        production_subtotal
        production_shipping
        production_total
        production_total_ex_gst
        store_subtotal
        store_discounts
        store_shipping
        customer_paid
        customer_paid_ex_gst
        gross_margin
        gross_margin_percentage
      ]

      orders.find_each do |order|
        fc = order.fulfillment_currency || order.currency

        total_ex_gst_cents = if order.gst_rate.zero?
          order.production_total_cents
        else
          (order.production_total_cents / (1 + order.gst_rate)).round
        end

        revenue_cents = (order.subtotal_price_cents || 0) - (order.total_tax_cents || 0)
        margin_cents = revenue_cents - total_ex_gst_cents
        margin_pct = if revenue_cents > 0 && total_ex_gst_cents > 0
          ((revenue_cents - total_ex_gst_cents).to_f / revenue_cents * 100).round(1)
        end

        csv << [
          order.created_at.to_date.iso8601,
          order.external_number,
          order.shopify_remote_order_name,
          order.production_subtotal.to_f,
          order.production_shipping.to_f,
          order.production_total.to_f,
          Money.new(total_ex_gst_cents, fc).to_f,
          order.subtotal_price.to_f,
          order.total_discounts.to_f,
          order.total_shipping.to_f,
          order.total_price.to_f,
          (order.total_price - order.total_tax).to_f,
          Money.new(margin_cents, order.currency).to_f,
          margin_pct
        ]
      end
    end

    puts "Exported to #{filepath}"
  end
end
