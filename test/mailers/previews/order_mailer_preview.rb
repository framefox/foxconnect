class OrderMailerPreview < ActionMailer::Preview
  # Preview at /rails/mailers/order_mailer/draft_imported
  def draft_imported
    order = sample_draft_order
    OrderMailer.with(order_id: order.id).draft_imported
  end

  # Preview at /rails/mailers/order_mailer/fulfillment_notification
  def fulfillment_notification
    fulfillment = sample_fulfillment
    OrderMailer.with(order_id: fulfillment.order_id, fulfillment_id: fulfillment.id).fulfillment_notification
  end

  private

  def sample_draft_order
    # Use an existing order if available to avoid seeding in preview
    existing = Order.includes(order_items: [ :product_variant, :variant_mapping ]).order(created_at: :desc).first
    return existing if existing

    # Fallback: build a lightweight order in memory (not persisted)
    store = Store.first || Store.new(name: "Demo Store", platform: "shopify", shopify_domain: "example.myshopify.com")
    order = Order.new(store: store, external_id: "1001", name: "#1001", currency: "USD")
    order.save!(validate: false)
    order.order_items.create!(title: "Frame A", variant_title: "Black 8x10", quantity: 1, price: 49.0, total: 49.0, discount_amount: 0, tax_amount: 0, requires_shipping: true)
    order.order_items.create!(title: "Frame B", variant_title: "White 5x7", quantity: 2, price: 29.0, total: 58.0, discount_amount: 0, tax_amount: 0, requires_shipping: true)
    order
  end

  def sample_fulfillment
    # Use an existing fulfillment if available
    existing = Fulfillment.includes(fulfillment_line_items: { order_item: [ :product_variant, :variant_mapping ] }, order: :order_items).recent.first
    return existing if existing

    # Fallback: create a sample fulfillment
    order = sample_draft_order
    fulfillment = order.fulfillments.create!(
      status: "success",
      tracking_company: "DHL",
      tracking_number: "1234567890",
      tracking_url: "https://www.dhl.com/track/1234567890",
      fulfilled_at: Time.current
    )

    # Add some items to the fulfillment
    order.order_items.limit(1).each do |item|
      fulfillment.fulfillment_line_items.create!(order_item: item, quantity: 1)
    end

    fulfillment
  end
end
