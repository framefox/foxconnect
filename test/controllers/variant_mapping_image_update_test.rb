require "test_helper"
require "minitest/mock"

class VariantMappingImageUpdateTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

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

  test "apply image recovers each target SKU preview and caches repeated SKUs" do
    attach_source_image
    first = target_mapping(456)
    second = target_mapping(789)
    third = target_mapping(456)
    lookups = []
    FrameSkuPreviewService.stub(:call, ->(frame_sku_id:, country_code:) {
      lookups << [frame_sku_id, country_code]
      "https://example.com/render/#{frame_sku_id}?artwork=placeholder"
    }) do
      post apply_image_to_all_variant_mapping_path(@mapping), params: {
        target_variant_ids: [first, second, third].map(&:product_variant_id)
      }, as: :json
    end
    assert_response :success
    assert_equal 3, response.parsed_body["updated_count"]
    assert_equal [[456, "NZ"], [789, "NZ"]], lookups
    [first, second, third].each do |target|
      target.reload
      assert_equal @mapping.image.external_image_id, target.image.external_image_id
      assert_not_equal @mapping[:image_id], target[:image_id]
      assert_includes target.preview_url, "/#{target.frame_sku_id}?"
      assert target.framed_preview_thumbnail.present?
    end
  end

  test "apply image preserves an existing target preview and respects selection" do
    attach_source_image
    selected = target_mapping(456, preview: "https://example.com/existing-render")
    unselected = target_mapping(789)
    FrameSkuPreviewService.stub(:call, ->(**) { flunk "Unexpected preview lookup" }) do
      post apply_image_to_all_variant_mapping_path(@mapping), params: {
        target_variant_ids: [selected.product_variant_id]
      }, as: :json
    end
    assert_response :success
    assert_equal "https://example.com/existing-render", selected.reload.preview_url
    assert selected.image.present?
    assert_nil unselected.reload[:image_id]
  end

  test "apply image lookup failure leaves every target unchanged" do
    attach_source_image
    first = target_mapping(456, preview: "https://example.com/existing-render")
    second = target_mapping(789)
    FrameSkuPreviewService.stub(:call, ->(**) { raise FrameSkuPreviewService::Unavailable, "Preview unavailable" }) do
      assert_no_difference "Image.count" do
        post apply_image_to_all_variant_mapping_path(@mapping), params: {
          target_variant_ids: [first.product_variant_id, second.product_variant_id]
        }, as: :json
      end
    end
    assert_response :unprocessable_entity
    assert_equal "Preview unavailable", response.parsed_body["error"]
    assert_nil first.reload[:image_id]
    assert_nil second.reload[:image_id]
  end

  test "apply image ignores targets removed from the store" do
    attach_source_image
    removed = target_mapping(456)
    removed.product_variant.update!(removed_from_source_at: Time.current)
    FrameSkuPreviewService.stub(:call, ->(**) { flunk "Unexpected preview lookup" }) do
      post apply_image_to_all_variant_mapping_path(@mapping), params: {
        target_variant_ids: [removed.product_variant_id]
      }, as: :json
    end
    assert_response :success
    assert_equal 0, response.parsed_body["updated_count"]
    assert_nil removed.reload[:image_id]
  end

  test "POST upsert recovers a missing preview" do
    attrs = payload[:variant_mapping].merge(
      product_variant_id: @mapping.product_variant_id, frame_sku_id: @mapping.frame_sku_id,
      frame_sku_code: @mapping.frame_sku_code, frame_sku_title: @mapping.frame_sku_title,
      frame_sku_cost_cents: @mapping.frame_sku_cost_cents, country_code: "NZ"
    )
    FrameSkuPreviewService.stub(:call, "https://example.com/recovered-render") do
      post variant_mappings_path, params: { variant_mapping: attrs }, as: :json
    end
    assert_response :success
    assert_equal "https://example.com/recovered-render", @mapping.reload.preview_url
    assert response.parsed_body["framed_preview_thumbnail"].present?
  end

  test "bulk overwrite fetches the new SKU preview and retains artwork" do
    attach_source_image
    old_image_id = @mapping[:image_id]
    request = @mapping.store.bulk_mapping_requests.create!(variant_title: "A1", frame_sku_title: "Updated", total_count: 1)
    FrameSkuPreviewService.stub(:call, ->(frame_sku_id:, country_code:) {
      assert_equal 456, frame_sku_id
      "https://example.com/new-render"
    }) do
      BulkMappingJob.perform_now(bulk_mapping_request_id: request.id, country_code: "NZ", overwrite: true,
        frame_sku_params: { "id" => 456, "code" => "NEW", "title" => "Updated", "cost_cents" => 1000 })
    end
    assert_equal 1, request.reload.created_count
    assert_equal "https://example.com/new-render", @mapping.reload.preview_url
    assert_equal old_image_id, @mapping[:image_id]
    assert @mapping.framed_preview_thumbnail.present?
  end

  test "bulk overwrite failure preserves existing product and artwork" do
    attach_source_image
    original = @mapping.attributes
    request = @mapping.store.bulk_mapping_requests.create!(variant_title: "A1", frame_sku_title: "Updated", total_count: 1)
    FrameSkuPreviewService.stub(:call, ->(**) { raise FrameSkuPreviewService::Unavailable, "Preview unavailable" }) do
      BulkMappingJob.perform_now(bulk_mapping_request_id: request.id, country_code: "NZ", overwrite: true,
        frame_sku_params: { "id" => 456, "code" => "NEW", "title" => "Updated", "cost_cents" => 1000 })
    end
    assert_equal original, @mapping.reload.attributes
    assert_equal 0, request.reload.created_count
    assert request.has_errors?
  end

  test "direct image saves queue recovery and the job repairs only preview metadata" do
    attach_source_image
    assert_enqueued_with(job: RecoverVariantMappingPreviewJob, args: [@mapping.id]) do
      @mapping.update!(preview_url: nil)
    end
    image_attributes = @mapping.image.attributes
    FrameSkuPreviewService.stub(:call, "https://example.com/recovered-render") do
      RecoverVariantMappingPreviewJob.perform_now(@mapping.id)
    end
    assert_equal "https://example.com/recovered-render", @mapping.reload.preview_url
    assert_equal image_attributes, @mapping.image.attributes
  end

  test "background recovery does not overwrite a concurrent product change" do
    attach_source_image
    @mapping.update!(preview_url: nil)
    FrameSkuPreviewService.stub(:call, ->(**) {
      @mapping.update_columns(frame_sku_id: 789, preview_url: "https://example.com/concurrent-render")
      "https://example.com/old-render"
    }) do
      RecoverVariantMappingPreviewJob.perform_now(@mapping.id)
    end
    assert_equal "https://example.com/concurrent-render", @mapping.reload.preview_url
  end

  test "background recovery skips repaired mappings and removed artwork" do
    attach_source_image
    FrameSkuPreviewService.stub(:call, ->(**) { flunk "Unexpected preview lookup" }) do
      RecoverVariantMappingPreviewJob.perform_now(@mapping.id)
      @mapping.update!(image: nil, preview_url: nil)
      RecoverVariantMappingPreviewJob.perform_now(@mapping.id)
    end
    assert_nil @mapping.reload[:image_id]
    assert_nil @mapping.preview_url
  end

  private

  def attach_source_image
    attributes = payload[:variant_mapping].except(:image_id, :preview_url)
    @mapping.update!(image: Image.create!(attributes.merge(external_image_id: 1150694)),
      preview_url: "https://example.com/source-render")
  end

  def target_mapping(sku, preview: nil)
    product = @mapping.product_variant.product
    position = product.product_variants.maximum(:position) + 1
    variant = product.product_variants.create!(title: "Target #{position}",
      external_variant_id: "target-#{position}", position: position)
    variant.variant_mappings.create!(bundle: variant.bundle, slot_position: 1,
      is_default: true, country_code: "NZ", frame_sku_id: sku, frame_sku_code: "SKU.#{sku}",
      frame_sku_title: "Target Frame", frame_sku_cost_cents: 1000,
      frame_sku_long: 400, frame_sku_short: 300, frame_sku_unit: "mm", preview_url: preview)
  end

  def payload
    { variant_mapping: { image_id: 1150694, image_key: "test-artwork", cloudinary_id: "hydrangeas",
      image_filename: "Hydrangeas", image_width: 9933, image_height: 14043,
      cx: 10, cy: 0, cw: 9921, ch: 14043, preview_url: nil } }
  end
end
