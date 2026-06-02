require "test_helper"

class OrderItemTest < ActiveSupport::TestCase
  test "duplicate_custom_item copies mappings and images without external line references" do
    order = create_order!
    item = order.order_items.create!(
      is_custom: true,
      variant_title: "Custom Print",
      quantity: 2,
      requires_shipping: true,
      external_line_id: "source-line",
      shopify_remote_line_item_id: "remote-line"
    )

    singular_mapping = create_variant_mapping!(image: create_image!(external_image_id: 101))
    item.update!(variant_mapping: singular_mapping)

    child_mapping = create_variant_mapping!(
      order_item: item,
      slot_position: 1,
      image: create_image!(external_image_id: 102)
    )

    duplicate = item.duplicate_custom_item!

    assert_not_equal item.id, duplicate.id
    assert_equal order.id, duplicate.order_id
    assert duplicate.is_custom?
    assert duplicate.active?
    assert_nil duplicate.external_line_id
    assert_nil duplicate.shopify_remote_line_item_id
    assert_equal "Custom Print", duplicate.variant_title
    assert_equal 2, duplicate.quantity

    assert_not_nil duplicate.variant_mapping
    assert_not_equal singular_mapping.id, duplicate.variant_mapping.id
    assert_not_equal singular_mapping.image.id, duplicate.variant_mapping.image.id
    assert_equal singular_mapping.image.external_image_id, duplicate.variant_mapping.image.external_image_id

    assert_equal 1, duplicate.variant_mappings.count
    copied_child_mapping = duplicate.variant_mappings.first
    assert_not_equal child_mapping.id, copied_child_mapping.id
    assert_not_equal child_mapping.image.id, copied_child_mapping.image.id
    assert_equal child_mapping.slot_position, copied_child_mapping.slot_position
    assert_equal child_mapping.image.external_image_id, copied_child_mapping.image.external_image_id
  end

  private

  def create_order!
    organization = Organization.create!(name: "Test Org #{SecureRandom.hex(6)}")

    Order.create!(
      organization: organization,
      external_id: "order-#{SecureRandom.hex(6)}",
      currency: "NZD",
      country_code: "NZ",
      subtotal_price_cents: 0,
      total_discounts_cents: 0,
      total_shipping_cents: 0,
      total_tax_cents: 0,
      total_price_cents: 0,
      production_subtotal_cents: 0,
      production_shipping_cents: 0,
      production_total_cents: 0
    )
  end

  def create_image!(external_image_id:)
    Image.create!(
      external_image_id: external_image_id,
      image_key: "image-#{external_image_id}",
      cloudinary_id: "cloudinary-#{external_image_id}",
      image_width: 1200,
      image_height: 1600,
      image_filename: "image-#{external_image_id}.jpg",
      cx: 10,
      cy: 20,
      cw: 800,
      ch: 1000
    )
  end

  def create_variant_mapping!(attributes = {})
    VariantMapping.create!({
      frame_sku_id: 1,
      frame_sku_code: "FRAME-1",
      frame_sku_title: "Black Frame",
      frame_sku_description: "Wood | Black",
      frame_sku_cost_cents: 1200,
      frame_sku_long: 297,
      frame_sku_short: 210,
      frame_sku_unit: "mm",
      width: 210,
      height: 297,
      unit: "mm",
      country_code: "NZ",
      is_default: false
    }.merge(attributes))
  end
end
