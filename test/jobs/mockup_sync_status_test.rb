require "test_helper"
require "minitest/mock"

class MockupSyncStatusTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Mockup tests")
    user = User.create!(email: "mockup-#{SecureRandom.hex(6)}@example.com", organization: organization)
    store = Store.create!(organization: organization, created_by_user: user,
      uid: SecureRandom.hex(6), platform: "shopify", name: "Mockup store",
      shopify_domain: "mockup-test.myshopify.com", shopify_token: "test", access_scopes: "read_products,write_products")
    @product = Product.create!(store: store, external_id: "123", title: "Mockup product", status: "active")
  end

  test "records completion for an empty sync" do
    job = SyncProductVariantMappingsJob.new
    @product.record_mockup_sync(job.job_id, "queued", {}, new_request: true)
    job.perform(@product.id)
    result = @product.reload.mockup_sync_result
    assert_equal "completed", result["status"]
    assert_equal 0, result["successful"]
  end

  test "removed products record a visible failure" do
    @product.update!(removed_from_source_at: Time.current)
    SyncProductVariantMappingsJob.new.perform(@product.id)
    assert_equal "failed", @product.reload.mockup_sync_result["status"]
    assert_includes @product.mockup_sync_result["errors"], "Product was removed from Shopify"
  end

  test "older jobs cannot overwrite a newer requested sync" do
    @product.record_mockup_sync("new-job", "queued", {}, new_request: true)
    @product.record_mockup_sync("old-job", "failed", { "errors" => [ "Old failure" ] })
    assert_equal "queued", @product.reload.mockup_sync_result["status"]
    assert_equal "new-job", @product.mockup_sync_result["job_id"]
  end

  test "batch failures are persisted for the product page" do
    variant = ProductVariant.create!(product: @product, external_variant_id: "456", title: "Variant", price: 10, fulfilment_active: true)
    mapping = Struct.new(:product_variant, :framed_preview_large, :frame_sku_title).new(variant, "https://example.com/mockup.jpg", "Frame")
    service = Object.new
    service.define_singleton_method(:batch_sync_variant_images) do |_data|
      { successful: 0, failed: 1, errors: [ { variant_id: "456", error: "Upload rejected" } ] }
    end
    scope = Object.new
    scope.define_singleton_method(:where) { |**_| [ variant ] }
    association = Object.new
    association.define_singleton_method(:present_in_source) { scope }
    Product.stub(:find, @product) do
      @product.stub(:product_variants, association) do
        variant.stub(:default_variant_mapping, mapping) do
          ShopifyVariantImageSyncService.stub(:new, service) do
            SyncProductVariantMappingsJob.new.perform(@product.id)
          end
        end
      end
    end
    result = @product.reload.mockup_sync_result
    assert_equal "failed", result["status"]
    assert_equal 1, result["failed"]
    assert_equal "Upload rejected", result["errors"].first["error"]
  end
end
