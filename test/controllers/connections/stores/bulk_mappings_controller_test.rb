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
  test "maps every confirmed partial title with its own SKU and never overwrites" do
    map_variant(@variant, 123)
    add_variant("A4")
    map_variant(add_variant("A3"), 456)
    add_variant("A3")
    map_variant(add_variant("A2"), 789)
    add_variant("A2")

    assert_enqueued_jobs 2, only: BulkMappingJob do
      post map_remaining_all_connections_store_bulk_mappings_path(@store), params: {
        variant_titles: ["A4", "A3", "A4"], overwrite: true
      }, as: :json
    end

    assert_response :success
    assert_equal ["A4", "A3"], response.parsed_body["queued"].map { |row| row["title"] }
    assert_empty response.parsed_body["skipped"]
    jobs = enqueued_jobs.select { |entry| entry[:job] == BulkMappingJob }.map { |entry| ActiveJob::Arguments.deserialize(entry[:args]).first }
    assert_equal [123, 456], jobs.map { |job| job[:frame_sku_params]["id"] }
    assert jobs.all? { |job| job[:overwrite] == false && job[:country_code] == "NZ" }
    assert_equal ["A3", "A4"], @store.bulk_mapping_requests.order(:variant_title).pluck(:variant_title)
    perform_enqueued_jobs only: BulkMappingJob
    assert @store.bulk_mapping_requests.all?(&:completed?)
    assert_equal 2, @store.bulk_mapping_requests.sum(:created_count)
    assert_equal 2, @store.bulk_mapping_requests.sum(:skipped_count)
    assert_equal [123], @store.product_variants.where(title: "A4").joins(:variant_mappings).distinct.pluck(:frame_sku_id)
    assert_equal [456], @store.product_variants.where(title: "A3").joins(:variant_mappings).distinct.pluck(:frame_sku_id)
  end

  test "conflicting mappings are reported while eligible rows are queued" do
    map_variant(@variant, 123)
    add_variant("A4")
    map_variant(add_variant("Conflict"), 456)
    map_variant(add_variant("Conflict"), 789)
    add_variant("Conflict")

    assert_enqueued_jobs 1, only: BulkMappingJob do
      post map_remaining_all_connections_store_bulk_mappings_path(@store), params: {
        variant_titles: ["Conflict", "A4"]
      }, as: :json
    end
    assert_response :success
    assert_equal ["A4"], response.parsed_body["queued"].map { |row| row["title"] }
    assert_equal "Conflict", response.parsed_body["skipped"].first["title"]
    assert_includes response.parsed_body["skipped"].first["error"], "Use Bulk Assign"
  end

  test "rechecks partial status and country rather than trusting the submitted list" do
    map_variant(@variant, 123)
    add_variant("Unmapped")
    map_variant(add_variant("AU only"), 456, country: "AU")
    add_variant("AU only")

    assert_no_enqueued_jobs only: BulkMappingJob do
      post map_remaining_all_connections_store_bulk_mappings_path(@store), params: {
        variant_titles: ["A4", "Unmapped", "AU only", "Missing"]
      }, as: :json
    end
    assert_response :success
    assert_empty response.parsed_body["queued"]
    assert_equal 4, response.parsed_body["skipped"].length
  end

  test "requires a list of titles" do
    post map_remaining_all_connections_store_bulk_mappings_path(@store), params: { variant_titles: "A4" }, as: :json
    assert_response :bad_request
  end

  test "cannot queue mappings for another organization's store" do
    other = Organization.create!(name: "Other bulk mapping organization")
    @store.update!(organization: other)
    assert_no_enqueued_jobs only: BulkMappingJob do
      post map_remaining_all_connections_store_bulk_mappings_path(@store), params: { variant_titles: ["A4"] }, as: :json
    end
    assert_response :not_found
  end

  private

  def add_variant(title)
    @variant.product.product_variants.create!(title: title, external_variant_id: SecureRandom.hex(8), position: @variant.product.product_variants.maximum(:position) + 1)
  end

  def map_variant(variant, sku, country: "NZ")
    variant.variant_mappings.create!(bundle: variant.bundle, slot_position: 1,
      is_default: true, country_code: country, frame_sku_id: sku,
      frame_sku_code: "SKU-#{sku}", frame_sku_title: "Frame #{sku}", frame_sku_cost_cents: 1000)
  end

end
