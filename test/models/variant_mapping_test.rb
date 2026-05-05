require "test_helper"

class VariantMappingTest < ActiveSupport::TestCase
  setup do
    Cloudinary.config.cloud_name = "test-cloud"
  end

  test "large framed preview uses a 1400 canvas with a 1250 artwork image" do
    url = build_mapping.framed_preview_large
    decoded_url = URI.decode_www_form_component(url)
    fully_decoded_url = URI.decode_www_form_component(decoded_url)

    assert_includes decoded_url, "h_1400"
    assert_includes decoded_url, "w_1400"
    assert_includes decoded_url, "maxPX=1120"
    assert_match(/c_fit,w_1250|w_1250,c_fit/, fully_decoded_url)
  end

  test "shopify variant sync uses the large framed preview by default" do
    mapping = build_mapping
    captured_args = nil

    mapping.store.define_singleton_method(:sync_shopify_variant_image) do |**kwargs|
      captured_args = kwargs
      { success: true }
    end

    assert_equal({ success: true }, mapping.sync_to_shopify_variant)

    decoded_url = URI.decode_www_form_component(captured_args[:image_url])
    fully_decoded_url = URI.decode_www_form_component(decoded_url)

    assert_equal "variant-123", captured_args[:shopify_variant_id]
    assert_equal "product-123", captured_args[:shopify_product_id]
    assert_includes decoded_url, "h_1400"
    assert_includes decoded_url, "w_1400"
    assert_includes decoded_url, "maxPX=1120"
    assert_match(/c_fit,w_1250|w_1250,c_fit/, fully_decoded_url)
  end

  private

  def build_mapping
    store = Store.new(platform: "shopify", mockup_bg_colour: "f4f4f4")
    product = Product.new(store: store, external_id: "product-123")
    product_variant = ProductVariant.new(product: product, external_variant_id: "variant-123")
    image = Image.new(
      external_image_id: 123,
      image_key: "artwork-key",
      cloudinary_id: "sample-artwork",
      image_width: 2500,
      image_height: 1800,
      image_filename: "artwork.jpg",
      cx: 10,
      cy: 20,
      cw: 2000,
      ch: 1400
    )

    VariantMapping.new(
      product_variant: product_variant,
      image: image,
      frame_sku_id: 456,
      frame_sku_code: "TEST-SKU",
      frame_sku_title: "Test SKU",
      frame_sku_cost_cents: 1000,
      frame_sku_long: 420,
      frame_sku_short: 297,
      frame_sku_unit: "mm",
      width: 420,
      height: 297,
      unit: "mm",
      country_code: "NZ",
      preview_url: "https://preview.example/preview.jpg?artwork=https://example.com/placeholder.jpg&pattern=dusty&mouldingWidth=20&frameType=box&artWidthMM=420&artHeightMM=297&matL=0&matR=0&matT=0&matB=0&matColor=fff&matCore=fff&maxPX=800"
    )
  end
end
