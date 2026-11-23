require "test_helper"

class SharedVariantArtworkTest < ActiveSupport::TestCase
  setup do
    Cloudinary.config.cloud_name = "test-cloud"
    org = Organization.create!(name: "Shared artwork")
    user = User.create!(email: "shared-artwork@example.com", organization: org, country: "NZ")
    @store = Store.create!(organization: org, created_by_user: user, name: "Artwork", platform: "shopify",
      shopify_domain: "shared-artwork.myshopify.com", shopify_token: "test", access_scopes: "read_products", active: false)
    product = @store.products.create!(title: "Print", external_id: "print")
    @variant = product.product_variants.create!(title: "A4", external_variant_id: "a4", position: 1)
    @artwork = Image.create!(external_image_id: 123, image_key: "art", cloudinary_id: "art", image_filename: "art.jpg",
      image_width: 1000, image_height: 1000, cx: 10, cy: 20, cw: 700, ch: 800)
    @nz = mapping("NZ", image: @artwork)
  end

  test "new AU mapping inherits artwork and crop but keeps its own SKU" do
    au = mapping("AU")
    assert_equal @artwork.id, au.image.id
    assert_equal @artwork.crop_coordinates, au.crop_coordinates
    assert_equal 222, au.frame_sku_id
    assert_equal 111, @nz.reload.frame_sku_id
    assert_equal 123, au.as_frontend_json["image_id"]
  end

  test "existing blank AU mapping sees NZ artwork without a data migration" do
    au = mapping("AU")
    au.update_columns(image_id: nil)
    assert_equal @artwork.id, au.reload.image.id
    assert_equal @artwork.crop_coordinates, au.crop_coordinates
    artwork_json = @variant.reload.shared_artwork_for_frontend.first
    assert_equal 123, artwork_json["image_id"]
    assert_equal 10, artwork_json["cx"]
    assert_not artwork_json.key?("frame_sku_id")
  end

  test "replacing and removing artwork applies to both countries but not other slots" do
    au = mapping("AU")
    @variant.bundle.update!(slot_count: 2)
    slot_two = mapping("NZ", slot: 2, image: @artwork)
    replacement = @artwork.dup
    replacement.assign_attributes(external_image_id: 456, cx: 50)
    replacement.save!
    au.update!(image: replacement)
    assert_equal replacement.id, @nz.reload.image.id
    assert_equal 50, @nz.cx
    assert_equal @artwork.id, slot_two.reload.image.id
    au.remove_shared_artwork!
    assert_nil @nz.reload.image
    assert_nil au.reload.image
    assert_equal @artwork.id, slot_two.reload.image.id
    assert_equal 111, @nz.frame_sku_id
    assert_equal 222, au.frame_sku_id
  end

  test "AU order snapshots shared crop and remains independent of future template edits" do
    mapping("AU")
    order = Order.create!(organization: @store.organization, store: @store, external_id: "au-order", currency: "AUD",
      country_code: "AU", subtotal_price_cents: 0, total_discounts_cents: 0, total_shipping_cents: 0,
      total_tax_cents: 0, total_price_cents: 0)
    item = order.order_items.create!(external_variant_id: "a4", quantity: 1, price_cents: 0, total_cents: 0,
      discount_amount_cents: 0, tax_amount_cents: 0, production_cost_cents: 0)
    snapshot = item.variant_mappings.first
    assert snapshot
    assert_equal "AU", snapshot.country_code
    assert_equal 222, snapshot.frame_sku_id
    assert_equal @artwork.crop_coordinates, snapshot.crop_coordinates
    assert_not_equal @artwork.id, snapshot.image.id
    @nz.remove_shared_artwork!
    assert_equal 123, snapshot.reload.image.external_image_id
    assert_equal 10, snapshot.cx
  end

  private

  def mapping(country, slot: 1, image: nil)
    @variant.variant_mappings.create!(bundle: @variant.bundle, slot_position: slot, country_code: country,
      image: image, frame_sku_id: country == "NZ" ? 111 : 222, frame_sku_code: "#{country}-FRAME",
      frame_sku_title: "A4", frame_sku_cost_cents: 1000, frame_sku_long: 297, frame_sku_short: 210,
      frame_sku_unit: "mm", preview_url: "https://example.com/#{country}/render")
  end
end
