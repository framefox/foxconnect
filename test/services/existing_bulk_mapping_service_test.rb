require "test_helper"

class ExistingBulkMappingServiceTest < ActiveSupport::TestCase
  setup do
    organization = Organization.create!(name: "Mapping test")
    @user = User.create!(email: "mapping-service@example.com", organization: organization)
    @store = Store.create!(name: "Mapping test", created_by_user: @user, platform: "shopify", shopify_token: "test-token", access_scopes: "read_products", shopify_domain: "mapping-test.myshopify.com", organization: organization, active: false)
    @product = @store.products.create!(title: "Art", external_id: "art")
    @source = variant("source")
    @target = variant("target")
    @mapping = map(@source)
  end

  test "reuses product settings without copying artwork and preserves mapped variants" do
    params = resolve
    refute params.key?("preview_image")
    refute params.key?("image_id")
    original = @mapping.attributes
    request = @store.bulk_mapping_requests.create!(variant_title: "A4", frame_sku_title: params["title"], total_count: 2)

    BulkMappingJob.perform_now(bulk_mapping_request_id: request.id, frame_sku_params: params, country_code: "NZ")

    assert_equal original, @mapping.reload.attributes
    copied = @target.variant_mappings.defaults.sole
    assert_equal @mapping.frame_sku_id, copied.frame_sku_id
    assert_equal @mapping.colour, copied.colour
    assert_nil copied.image_id
    assert_nil copied.preview_url
    assert_equal "completed", request.reload.status
    assert_equal 1, request.created_count
    assert_equal 1, request.skipped_count
  end

  test "rejects conflicting product mappings" do
    map(@target, frame_sku_id: 456)
    assert_raises(ExistingBulkMappingService::Unavailable) { resolve }
  end

  test "accepts equivalent mappings with different prices and previews" do
    map(@target, frame_sku_cost_cents: 2500, preview_url: "https://example.com/other-artwork.jpg")
    assert_equal @mapping.frame_sku_id, resolve["id"]
  end

  test "ignores mappings for other countries titles stores and removed variants" do
    @mapping.update!(country_code: "AU")
    map(variant("other-title", title: "A3"))
    map(variant("removed", removed_from_source_at: Time.current))
    other_store = Store.create!(name: "Other", created_by_user: @user, platform: "shopify", shopify_token: "test-token", access_scopes: "read_products", shopify_domain: "other-mapping-test.myshopify.com", organization: @store.organization, active: false)
    other_product = other_store.products.create!(title: "Other", external_id: "other")
    map(other_product.product_variants.create!(title: "A4", external_variant_id: "other", position: 1))

    assert_raises(ExistingBulkMappingService::Unavailable) { resolve }
  end

  test "rejects multi slot bundles" do
    @source.bundle.update!(slot_count: 2)
    assert_raises(ExistingBulkMappingService::Unavailable) { resolve }
  end

  private

  def variant(id, **attributes)
    @product.product_variants.create!({ title: "A4", external_variant_id: id, position: @product.product_variants.count + 1 }.merge(attributes))
  end

  def map(variant, **attributes)
    variant.variant_mappings.create!({
      bundle: variant.bundle, slot_position: 1, is_default: true, country_code: "NZ",
      frame_sku_id: 123, frame_sku_code: "A4-BLACK", frame_sku_title: "A4 Black",
      frame_sku_cost_cents: 1000, frame_sku_long: 297, frame_sku_short: 210,
      frame_sku_unit: "mm", colour: "Black", preview_url: "https://example.com/artwork.jpg"
    }.merge(attributes))
  end

  def resolve
    ExistingBulkMappingService.call(store: @store, variant_title: "A4", country_code: "NZ")
  end
end
