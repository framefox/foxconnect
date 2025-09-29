# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Examples:
#
#   movies = Movie.create([{ name: "Star Wars" }, { name: "Lord of the Rings" }])
#   Character.create(name: "Luke", movie: movies.first)

# Example of how orders work with variant mappings
# This demonstrates the relationship between orders, order_items, and variant_mappings

# Create a test store if one doesn't exist
if Store.count == 0
  store = Store.create!(
    name: "Test Store",
    platform: "shopify",
    shopify_domain: "test-store.myshopify.com",
    shopify_token: "test_token"
  )

  # Create a test product
  product = Product.create!(
    store: store,
    external_id: 123456789,
    title: "Custom Framed Art Print",
    handle: "custom-framed-art-print",
    product_type: "Art",
    vendor: "FoxConnect",
    status: "active"
  )

  # Create a test variant
  variant = ProductVariant.create!(
    product: product,
    external_variant_id: 987654321,
    title: "16x20 Black Frame",
    sku: "FRAME-16x20-BLACK",
    price: 89.99,
    position: 1
  )

  # Create a variant mapping (this connects the variant to our fulfillment system)
  mapping = VariantMapping.create!(
    product_variant: variant,
    image_id: 12345,
    image_key: "test-artwork-key",
    frame_sku_id: 67890,
    frame_sku_code: "BLK-16x20",
    frame_sku_title: "Black Wood Frame 16x20",
    cx: 100, cy: 100, cw: 400, ch: 300,
    preview_url: "https://example.com/preview"
  )

  puts "✓ Created test store, product, variant, and mapping"
end

# Example of creating an order with automatic variant mapping resolution
if Order.count == 0 && Store.first
  store = Store.first

  order = Order.create!(
    store: store,
    external_id: "shopify_order_12345",
    external_number: "1001",
    name: "#1001",
    customer_email: "customer@example.com",
    currency: "USD",
    subtotal_price: 89.99,
    total_price: 89.99,
    financial_status: "paid",
    fulfillment_status: "unfulfilled",
    processed_at: Time.current
  )

  # Create shipping address
  shipping_address = ShippingAddress.create!(
    order: order,
    first_name: "John",
    last_name: "Doe",
    address1: "123 Main Street",
    city: "San Francisco",
    province: "California",
    province_code: "CA",
    postal_code: "94102",
    country: "United States",
    country_code: "US"
  )

  # Create order item - this will automatically resolve the variant mapping
  # based on the external_variant_id matching our ProductVariant
  order_item = OrderItem.create!(
    order: order,
    external_variant_id: "987654321", # This matches our test variant
    title: "Custom Framed Art Print",
    variant_title: "16x20 Black Frame",
    sku: "FRAME-16x20-BLACK",
    quantity: 1,
    price: 89.99,
    total: 89.99
  )

  puts "✓ Created test order with shipping address and order item"
  puts "✓ Order item automatically linked to variant mapping: #{order_item.has_variant_mapping?}"

  if order_item.variant_mapping
    puts "  - Mapped to frame: #{order_item.variant_mapping.frame_sku_title}"
    puts "  - Can fulfill: #{order_item.can_fulfill?}"
  end
end
