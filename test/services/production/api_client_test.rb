require "test_helper"

class Production::ApiClientTest < ActiveSupport::TestCase
  setup do
    suffix = SecureRandom.hex(6)

    @organization = Organization.create!(name: "Production API Test #{suffix}")
    @user = User.create!(
      email: "production-api-#{suffix}@example.com",
      organization: @organization,
      country: "NZ"
    )
    @store = Store.create!(
      name: "Production API Store #{suffix}",
      platform: "squarespace",
      squarespace_domain: "production-api-#{suffix}.squarespace.com",
      organization: @organization,
      created_by_user: @user
    )
    @product = @store.products.create!(
      external_id: "product-#{suffix}",
      title: "Mother-Daughter Journey II",
      handle: "mother-daughter-journey-ii-#{suffix}"
    )
    @variant = @product.product_variants.create!(
      external_variant_id: "variant-#{suffix}",
      title: "S: A3 | 29.7 x 42cm / Black",
      sku: "PR00605A3Bl",
      fulfilment_active: true
    )
    @order = @store.orders.create!(
      external_id: "order-#{suffix}",
      name: "#6369",
      currency: "NZD",
      fulfillment_currency: "NZD",
      country_code: "NZ",
      organization: @organization
    )
  end

  test "uses direct single-slot order item override ahead of copied template mapping" do
    create_mapping!(
      frame_sku_id: 1310,
      frame_sku_code: "FXRS14.175.1.67",
      frame_sku_cost_cents: 7000,
      image: create_image!(external_image_id: 894644),
      bundle: @variant.bundle,
      slot_position: 1
    )

    order_item = create_order_item!
    copied_mapping = order_item.variant_mappings.first
    override_mapping = create_mapping!(
      frame_sku_id: 59951,
      frame_sku_code: "HBFX-RAG-UNFRAMED-PRINT-420-x-297mm",
      frame_sku_cost_cents: 4500,
      image: create_image!(external_image_id: 974816)
    )

    order_item.update!(variant_mapping: override_mapping)

    assert_equal [ override_mapping ], order_item.production_variant_mappings
    assert_equal [], order_item.variant_mappings_for_frontend
    assert @order.all_variant_mappings_have_images?

    payload_items = Production::ApiClient.new(order: @order).send(:build_payload).dig(:draft_order, :draft_order_items)

    assert_equal [ 59951 ], payload_items.map { |item| item[:frame_sku_id] }
    assert_equal [ override_mapping.id ], payload_items.map { |item| item[:variant_mapping_id] }
    assert_not_includes payload_items.map { |item| item[:variant_mapping_id] }, copied_mapping.id
  end

  test "uses ordered slot mappings for multi-slot bundles" do
    @variant.bundle.update!(slot_count: 2)

    create_mapping!(
      frame_sku_id: 1310,
      frame_sku_code: "FXRS14.175.1.67",
      image: create_image!(external_image_id: 894644),
      bundle: @variant.bundle,
      slot_position: 1
    )
    create_mapping!(
      frame_sku_id: 59951,
      frame_sku_code: "HBFX-RAG-UNFRAMED-PRINT-420-x-297mm",
      image: create_image!(external_image_id: 974816),
      bundle: @variant.bundle,
      slot_position: 2
    )

    order_item = create_order_item!
    payload_items = Production::ApiClient.new(order: @order).send(:build_payload).dig(:draft_order, :draft_order_items)

    assert_equal 2, order_item.production_variant_mappings.count
    assert_equal [ 1310, 59951 ], payload_items.map { |item| item[:frame_sku_id] }
  end

  private

  def create_order_item!
    @order.order_items.create!(
      product_variant: @variant,
      external_variant_id: @variant.external_variant_id,
      title: @product.title,
      variant_title: @variant.title,
      sku: @variant.sku,
      quantity: 1,
      price_cents: 12000,
      total_cents: 12000,
      discount_amount_cents: 0,
      tax_amount_cents: 0,
      production_cost_cents: 0,
      requires_shipping: true
    )
  end

  def create_mapping!(frame_sku_id:, frame_sku_code:, image:, frame_sku_cost_cents: 4500, bundle: nil, slot_position: nil)
    VariantMapping.create!(
      product_variant: @variant,
      bundle: bundle,
      slot_position: slot_position,
      image: image,
      frame_sku_id: frame_sku_id,
      frame_sku_code: frame_sku_code,
      frame_sku_title: "420 x 297mm (A3)",
      frame_sku_description: "Printing: Ilford Smooth Cotton Rag | Frame: Test",
      frame_sku_cost_cents: frame_sku_cost_cents,
      frame_sku_long: 420,
      frame_sku_short: 297,
      frame_sku_unit: "mm",
      country_code: "NZ",
      is_default: false,
      preview_url: "https://example.com/preview.jpg"
    )
  end

  def create_image!(external_image_id:)
    Image.create!(
      external_image_id: external_image_id,
      image_key: SecureRandom.hex(4),
      cloudinary_id: SecureRandom.hex(8),
      image_width: 9933,
      image_height: 13984,
      image_filename: "A Mother-Daughter Journey 2",
      cx: 20,
      cy: 0,
      cw: 9892,
      ch: 13984
    )
  end
end
