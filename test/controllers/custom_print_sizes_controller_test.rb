require "test_helper"
require "minitest/mock"

class CustomPrintSizesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = users(:one)
    @user.update!(organization: Organization.create!(name: "Custom size tests"))
    sign_in @user
  end

  test "saves and returns material on create and index" do
    post custom_print_sizes_path, params: { custom_print_size: attributes }, as: :json
    assert_response :created
    assert_equal "canvas", response.parsed_body["material_type"]
    assert_equal "canvas", @user.custom_print_sizes.last.material_type
    get custom_print_sizes_path, as: :json
    assert_response :success
    assert_equal ["canvas"], response.parsed_body.map { |size| size["material_type"] }
  end

  test "rejects new sizes without material" do
    assert_no_difference "CustomPrintSize.count" do
      post custom_print_sizes_path, params: { custom_print_size: attributes.except(:material_type) }, as: :json
    end
    assert_response :unprocessable_entity
  end

  test "returns legacy sizes without assuming paper" do
    size = @user.custom_print_sizes.create!(attributes)
    size.update_column(:material_type, nil)
    get custom_print_sizes_path, as: :json
    assert_response :success
    assert_nil response.parsed_body.first["material_type"]
  end

  test "updates material and pricing while removing stale saved entries" do
    size = @user.custom_print_sizes.create!(attributes)
    saved = @user.organization.saved_items.create!(frame_sku_id: 101, custom_print_size: size)

    patch custom_print_size_path(size), params: { custom_print_size: attributes.merge(
      material_type: "paper", frame_sku_size_id: 40, frame_sku_size_description: "400×400mm"
    ) }, as: :json

    assert_response :success
    assert_equal "paper", size.reload.material_type
    assert_equal 40, size.frame_sku_size_id
    assert_equal "Paper · 40×40cm (Priced as 400×400mm)", response.parsed_body["full_description"]
    assert_not SavedItem.exists?(saved.id)
  end

  test "unchanged edit preserves saved entries" do
    size = @user.custom_print_sizes.create!(attributes)
    saved = @user.organization.saved_items.create!(frame_sku_id: 101, custom_print_size: size)
    patch custom_print_size_path(size), params: { custom_print_size: attributes }, as: :json
    assert_response :success
    assert SavedItem.exists?(saved.id)
  end

  test "invalid edit preserves size and saved entries" do
    size = @user.custom_print_sizes.create!(attributes)
    saved = @user.organization.saved_items.create!(frame_sku_id: 101, custom_print_size: size)
    patch custom_print_size_path(size), params: { custom_print_size: attributes.merge(long: -1) }, as: :json
    assert_response :unprocessable_entity
    assert_equal 40, size.reload.long
    assert SavedItem.exists?(saved.id)
  end

  test "legacy size can be classified by editing" do
    size = @user.custom_print_sizes.create!(attributes)
    size.update_column(:material_type, nil)
    patch custom_print_size_path(size), params: { custom_print_size: attributes }, as: :json
    assert_response :success
    assert_equal "canvas", size.reload.material_type
  end

  test "deletes size and its saved entries without affecting other sizes" do
    size = @user.custom_print_sizes.create!(attributes)
    saved = @user.organization.saved_items.create!(frame_sku_id: 101, custom_print_size: size)
    other = @user.custom_print_sizes.create!(attributes)
    delete custom_print_size_path(size), as: :json
    assert_response :no_content
    assert_not CustomPrintSize.exists?(size.id)
    assert_not SavedItem.exists?(saved.id)
    assert CustomPrintSize.exists?(other.id)
  end

  test "cannot edit another user's size" do
    size = users(:two).custom_print_sizes.create!(attributes)
    patch custom_print_size_path(size), params: { custom_print_size: attributes.merge(long: 50) }, as: :json
    assert_response :not_found
    assert_equal 40, size.reload.long
  end

  test "cannot delete another user's size" do
    size = users(:two).custom_print_sizes.create!(attributes)
    delete custom_print_size_path(size), as: :json
    assert_response :not_found
    assert_equal 40, size.reload.long
  end

  test "store settings mounts the custom sizes manager" do
    store = @user.organization.stores.create!(name: "Sizes store", created_by_user: @user,
      platform: "shopify", shopify_domain: "custom-size-tests.myshopify.com",
      shopify_token: "test-token", access_scopes: "read_products", active: false)
    CountryConfig.stub(:for_country, { "api_url" => "https://frame.example", "api_base_path" => "/api" }) do
      get settings_connections_store_path(store)
    end
    assert_response :success
    assert_select "h2", text: "Custom Sizes"
    assert_select '[data-react-component="CustomSizesManager"]', count: 1
  end

  private

  def attributes
    { long: 40, short: 40, unit: "cm", material_type: "canvas",
      frame_sku_size_id: 42, frame_sku_size_description: "420×420mm" }
  end
end
