require "test_helper"
require "minitest/mock"

class VariantMappingImageUpdateTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    Cloudinary.config.cloud_name = "test-cloud"
    organization = Organization.create!(name: "Image update test")
    user = User.create!(email: "image-update@example.com", organization: organization, country: "NZ")
    store = organization.stores.create!(created_by_user: user, name: "Image update", platform: "shopify", shopify_domain: "image-update.myshopify.com", shopify_token: "test", access_scopes: "read_products", active: false)
    product = store.products.create!(title: "Art", external_id: "art")
    variant = product.product_variants.create!(title: "A1", external_variant_id: "a1", position: 1)
    @mapping = variant.variant_mappings.create!(bundle: variant.bundle, slot_position: 1,
      is_default: true, country_code: "NZ", frame_sku_id: 123, frame_sku_code: "CANVAS.A1",
      frame_sku_title: "A1 Canvas", frame_sku_cost_cents: 23900, frame_sku_long: 841,
      frame_sku_short: 594, frame_sku_unit: "mm")
    sign_in user, scope: :user
  end

  test "attaching artwork recovers the preview for a reused mapping" do
    fetch_preview = ->(frame_sku_id:, country_code:) {
      assert_equal 123, frame_sku_id
      assert_equal "NZ", country_code
      "https://example.com/render?artwork=placeholder"
    }
    FrameSkuPreviewService.stub(:call, fetch_preview) do
      put variant_mapping_path(@mapping), params: payload, as: :json
    end
    assert_response :success
    assert @mapping.reload.image.present?
    assert_includes @mapping.preview_url, "/render"
    assert response.parsed_body["framed_preview_thumbnail"].present?
    assert_equal 1150694, response.parsed_body["image_id"]
  end

  test "existing preview does not need a lookup" do
    @mapping.update!(preview_url: "https://example.com/render?artwork=placeholder")
    FrameSkuPreviewService.stub(:call, ->(**) { flunk "Unexpected preview lookup" }) do
      put variant_mapping_path(@mapping), params: { variant_mapping: payload[:variant_mapping].except(:preview_url) }, as: :json
    end
    assert_response :success
    assert response.parsed_body["framed_preview_thumbnail"].present?
  end

  test "preview lookup failure is shown instead of a misleading success" do
    FrameSkuPreviewService.stub(:call, ->(**) { raise FrameSkuPreviewService::Unavailable, "Preview unavailable" }) do
      put variant_mapping_path(@mapping), params: payload, as: :json
    end
    assert_response :unprocessable_entity
    assert_equal ["Preview unavailable"], response.parsed_body["errors"]
    assert_nil @mapping.reload[:image_id]
  end

  private

  def payload
    { variant_mapping: { image_id: 1150694, image_key: "test-artwork", cloudinary_id: "hydrangeas",
      image_filename: "Hydrangeas", image_width: 9933, image_height: 14043,
      cx: 10, cy: 0, cw: 9921, ch: 14043, preview_url: nil } }
  end
end
