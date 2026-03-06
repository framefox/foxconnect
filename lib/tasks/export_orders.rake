require "csv"

namespace :export do
  desc "Export fulfilled orders to CSV. Optional SKU cost adjustment: ADJUST_SKU= ADJUST_AMOUNT=16"
  task orders: :environment do
    domain = ENV.fetch("DOMAIN") { abort "Usage: rake export:orders DOMAIN=example.myshopify.com" }

    store = Store.find_by(shopify_domain: domain)
    abort "Store not found for domain: #{domain}" unless store

    orders = store.orders.where(aasm_state: "fulfilled").order(:created_at)

    puts "Store: #{store.name} (#{domain})"
    puts "Fulfilled orders: #{orders.count}"

    adjust_sku = ENV["ADJUST_SKU"]
    adjust_cents = ((ENV["ADJUST_AMOUNT"]&.to_f || 0) * 100).to_i

    sku_counts = {}
    if adjust_sku.present? && adjust_cents > 0
      orders.includes(order_items: [:variant_mapping, :variant_mappings]).find_each do |order|
        count = 0
        order.order_items.select(&:active?).each do |item|
          new_style = item.variant_mappings.count { |vm| vm.frame_sku_code == adjust_sku }
          count += new_style * item.quantity
          if new_style.zero? && item.variant_mapping&.frame_sku_code == adjust_sku
            count += item.quantity
          end
        end
        sku_counts[order.id] = count if count > 0
      end

      puts "SKU adjustment: #{adjust_sku} @ -$#{"%.2f" % (adjust_cents / 100.0)} x #{sku_counts.values.sum} instances across #{sku_counts.size} orders"
    end

    filename = "fulfilled_orders_#{domain.split('.').first}_#{Date.today.iso8601}.csv"
    filepath = Rails.root.join("tmp", filename)

    CSV.open(filepath, "w") do |csv|
      headers = %w[
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
      headers.insert(3, "sku_adjustment_count", "sku_adjustment_total") if adjust_sku.present?
      csv << headers

      orders.find_each do |order|
        instances = sku_counts[order.id] || 0
        discount_cents = instances * adjust_cents
        fc = order.fulfillment_currency || order.currency

        adj_subtotal_cents = order.production_subtotal_cents - discount_cents
        adj_total_cents    = order.production_total_cents - discount_cents
        adj_total_ex_gst_cents = if order.gst_rate.zero?
          adj_total_cents
        else
          (adj_total_cents / (1 + order.gst_rate)).round
        end

        revenue_cents = (order.subtotal_price_cents || 0) - (order.total_tax_cents || 0)
        adj_margin_cents = revenue_cents - adj_total_ex_gst_cents
        adj_margin_pct = if revenue_cents > 0 && adj_total_ex_gst_cents > 0
          ((revenue_cents - adj_total_ex_gst_cents).to_f / revenue_cents * 100).round(1)
        end

        row = [
          order.created_at.to_date.iso8601,
          order.external_number,
          order.shopify_remote_order_name,
          Money.new(adj_subtotal_cents, fc).to_f,
          order.production_shipping.to_f,
          Money.new(adj_total_cents, fc).to_f,
          Money.new(adj_total_ex_gst_cents, fc).to_f,
          order.subtotal_price.to_f,
          order.total_discounts.to_f,
          order.total_shipping.to_f,
          order.total_price.to_f,
          (order.total_price - order.total_tax).to_f,
          Money.new(adj_margin_cents, order.currency).to_f,
          adj_margin_pct
        ]
        if adjust_sku.present?
          row.insert(3, instances, instances > 0 ? -Money.new(discount_cents, fc).to_f : 0)
        end
        csv << row
      end
    end

    puts "Exported to #{filepath}"
  end
end
