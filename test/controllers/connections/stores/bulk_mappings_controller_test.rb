require "test_helper"

class Connections::Stores::BulkMappingsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  setup do
    organization = Organization.create!(name: "Bulk mapping test")
    user = User.create!(email: "bulk-mapping@example.com", organization: organization, country: "NZ")
    @store = organization.stores.create!(name: "Bulk mapping", created_by_user: user, platform: "shopify", shopify_token: "test-token", access_scopes: "read_products", shopify_domain: "mapping-test.myshopify.com", active: false)
    product = @store.products.create!(title: "Art", external_id: "art")
    @variant = product.product_variants.create!(title: "A4", external_variant_id: "a4", position: 1)
    sign_in user, scope: :user
  end

  test "reuse resolves the existing SKU on the server and never overwrites" do
    @variant.variant_mappings.create!(bundle: @variant.bundle, slot_position: 1,
      is_default: true, country_code: "NZ", frame_sku_id: 123,
      frame_sku_code: "A4", frame_sku_title: "A4 frame", frame_sku_cost_cents: 1000)

    assert_enqueued_jobs 1, only: BulkMappingJob do
      post connections_store_bulk_mappings_path(@store), params: {
        variant_title: "A4", reuse_existing: true, overwrite: true,
        frame_sku: { id: 999 }
      }, as: :json
    end

    assert_response :success
    assert response.parsed_body["success"]
    request = @store.bulk_mapping_requests.sole
    assert_equal "A4 frame", request.frame_sku_title
    assert_includes response.parsed_body["redirect_url"], "request_id=#{request.id}"
    job = enqueued_jobs.find { |entry| entry[:job] == BulkMappingJob }
    arguments = ActiveJob::Arguments.deserialize(job[:args]).first
    assert_equal false, arguments[:overwrite]
    assert_equal 123, arguments[:frame_sku_params]["id"]
  end

  test "missing existing mapping returns an actionable error without queueing a job" do
    assert_no_enqueued_jobs only: BulkMappingJob do
      post connections_store_bulk_mappings_path(@store), params: { variant_title: "A4", reuse_existing: true }, as: :json
    end
    assert_response :unprocessable_entity
    assert_includes response.parsed_body["error"], "Use Bulk Assign"
    assert_empty @store.bulk_mapping_requests
  end
end
