class OrderMailerPreview < ActionMailer::Preview
  # Preview at /rails/mailers/order_mailer/draft_imported
  def draft_imported
    order = sample_draft_order
    OrderMailer.with(order_id: order.id).draft_imported
  end

  private

  def sample_draft_order
    # Use an existing order if available to avoid seeding in preview
    existing = Order.includes(order_items: [ :product_variant, :variant_mapping ]).order(created_at: :desc).first
    return existing if existing

    # Fallback: build a lightweight order in memory (not persisted)
    store = Store.first || Store.new(name: "Demo Store", platform: "shopify", shopify_domain: "example.myshopify.com")
    order = Order.new(store: store, external_id: "1001", name: "#1001", customer_email: "customer@example.com", currency: "USD")
    order.save!(validate: false)
    order.order_items.create!(title: "Frame A", variant_title: "Black 8x10", quantity: 1, price: 49.0, total: 49.0, discount_amount: 0, tax_amount: 0, requires_shipping: true)
    order.order_items.create!(title: "Frame B", variant_title: "White 5x7", quantity: 2, price: 29.0, total: 58.0, discount_amount: 0, tax_amount: 0, requires_shipping: true)
    order
  end
end
