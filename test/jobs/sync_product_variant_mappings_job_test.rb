require "test_helper"

class SyncProductVariantMappingsJobTest < ActiveJob::TestCase
  setup do
    Cloudinary.config.cloud_name = "test-cloud"
  end

  test "shopify batch sync sends large framed previews" do
    product = create_shopify_product_with_default_mapping
    fake_service = FakeShopifyVariantImageSyncService.new

    with_fake_shopify_sync_service(fake_service) do
      result = SyncProductVariantMappingsJob.perform_now(product.id)
      assert_equal 1, result[:synced]
      assert_empty result[:errors]
    end

    data = fake_service.batch_payload.first
    decoded_url = URI.decode_www_form_component(data[:image_url])
    fully_decoded_url = URI.decode_www_form_component(decoded_url)

    assert_equal product.default_variant.external_variant_id, data[:shopify_variant_id]
    assert_equal product.external_id, data[:shopify_product_id]
    assert_includes decoded_url, "h_2000"
    assert_includes decoded_url, "w_2000"
    assert_includes decoded_url, "maxPX=1600"
    assert_match(/c_fit,w_2000|w_2000,c_fit/, fully_decoded_url)
  end

  private

  class FakeShopifyVariantImageSyncService
    attr_reader :batch_payload

    def batch_sync_variant_images(variant_image_data)
      @batch_payload = variant_image_data
      { successful: variant_image_data.length, failed: 0, errors: [] }
    end

    def fetch_product_featured_image(_shopify_product_id)
      { success: true, image_url: nil }
    end
  end

  def with_fake_shopify_sync_service(fake_service)
    original_new = ShopifyVariantImageSyncService.method(:new)
    ShopifyVariantImageSyncService.define_singleton_method(:new) { |_store| fake_service }
    yield
  ensure
    ShopifyVariantImageSyncService.define_singleton_method(:new) do |*args, **kwargs, &block|
      original_new.call(*args, **kwargs, &block)
    end
  end

  def create_shopify_product_with_default_mapping
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Test Org #{suffix}")
    user = User.create!(email: "user-#{suffix}@example.com", organization: organization)
    store = Store.create!(
      name: "Test Shopify Store #{suffix}",
      platform: "shopify",
      shopify_domain: "test-#{suffix}.myshopify.com",
      shopify_token: "test-token",
      access_scopes: "read_products,write_products",
      active: true,
      organization: organization,
      created_by_user: user,
      mockup_bg_colour: "f4f4f4"
    )
    product = Product.create!(
      store: store,
      external_id: "product-#{suffix}",
      title: "Test Product",
      handle: "test-product-#{suffix}",
      status: "active"
    )
    variant = ProductVariant.create!(
      product: product,
      external_variant_id: "variant-#{suffix}",
      title: "Default",
      position: 1,
      fulfilment_active: true
    )
    image = Image.create!(
      external_image_id: rand(1..1_000_000),
      image_key: "artwork-key-#{suffix}",
      cloudinary_id: "sample-artwork",
      image_width: 2500,
      image_height: 1800,
      image_filename: "artwork.jpg",
      cx: 10,
      cy: 20,
      cw: 2000,
      ch: 1400
    )

    VariantMapping.create!(
      product_variant: variant,
      image: image,
      frame_sku_id: 456,
      frame_sku_code: "TEST-SKU-#{suffix}",
      frame_sku_title: "Test SKU",
      frame_sku_cost_cents: 1000,
      frame_sku_long: 420,
      frame_sku_short: 297,
      frame_sku_unit: "mm",
      country_code: "NZ",
      is_default: true,
      preview_url: "https://preview.example/preview.jpg?artwork=https://example.com/placeholder.jpg&pattern=dusty&mouldingWidth=20&frameType=box&artWidthMM=420&artHeightMM=297&matL=0&matR=0&matT=0&matB=0&matColor=fff&matCore=fff&maxPX=800"
    )

    product.reload
  end
end
