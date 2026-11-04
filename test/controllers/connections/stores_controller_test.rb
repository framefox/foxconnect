require "test_helper"
require "minitest/mock"

class Connections::StoresControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @organization = Organization.create!(name: "Store page #{SecureRandom.hex(4)}")
    @user = User.create!(email: "store-page-#{SecureRandom.hex(4)}@example.com", organization: @organization)
    @store = Store.create!(
      organization: @organization,
      created_by_user: @user,
      name: "Urban Road",
      platform: "shopify",
      shopify_domain: "urban-road-page-#{SecureRandom.hex(4)}.myshopify.com",
      shopify_token: "test-token",
      access_scopes: "read_products",
      uid: "urban-road-page-#{SecureRandom.hex(4)}"
    )
    product = Product.create!(store: @store, external_id: "101", title: "Harbour Print", handle: "harbour-print", status: "active")
    ProductVariant.create!(product: product, external_variant_id: "201", title: "A4 / None", position: 1, price: 20, fulfilment_active: true)
    ProductVariant.create!(product: product, external_variant_id: "202", title: "A3 / None", position: 2, price: 30, fulfilment_active: false)
    sign_in @user, scope: :user
  end

  test "product page counts variants without loading variant rows" do
    queries = nil
    CountryConfig.stub(:for_country, { "api_url" => "https://frame.example", "api_base_path" => "/api" }) do
      queries = capture_sql { get connections_store_path(@store) }
    end

    assert_response :success
    assert_match "1 products", response.body
    assert_match "2 variants", response.body
    assert_match "Harbour Print", response.body
    assert_match(/activeVariants(?:&quot;|"):1/, response.body)
    assert_match(/totalVariants(?:&quot;|"):2/, response.body)
    assert_no_match(/SELECT "product_variants"\."(title|metadata|selected_options|image_url)"/, queries.join("\n"))
    assert_not_includes queries.join("\n"), "LEFT OUTER JOIN \"product_variants\""
    variant_counts = queries.count { |sql| sql.include?("product_variants") && sql.match?(/COUNT\(/i) }
    assert_operator variant_counts, :<=, 3, queries.grep(/product_variants/).join("\n")
  end

  test "search results can enable and disable fulfilment for every matching product" do
    matching = Product.create!(store: @store, external_id: "canvas-1", title: "Canvas Art Print", handle: "canvas-art-print", status: "active")
    matching_variant = ProductVariant.create!(product: matching, external_variant_id: "c1", title: "60x60", position: 1, price: 10, fulfilment_active: false)
    removed_variant = ProductVariant.create!(product: matching, external_variant_id: "c2", title: "Removed", position: 2, price: 10, fulfilment_active: true, removed_from_source_at: Time.current)
    by_variant = Product.create!(store: @store, external_id: "canvas-2", title: "Other artwork", handle: "other-artwork", status: "active")
    variant_match = ProductVariant.create!(product: by_variant, external_variant_id: "c3", title: "Canvas Art Print size", position: 1, price: 10, fulfilment_active: false)
    other = Product.create!(store: @store, external_id: "frame-1", title: "Black Frame", handle: "black-frame", status: "active")
    other_variant = ProductVariant.create!(product: other, external_variant_id: "f1", title: "A4", position: 1, price: 10, fulfilment_active: false)

    CountryConfig.stub(:for_country, { "api_url" => "https://frame.example", "api_base_path" => "/api" }) do
      get connections_store_path(@store, search: "Canvas Art Print")
    end
    assert_response :success
    assert_match "Enable fulfilment", response.body
    assert_match "Disable fulfilment", response.body
    assert_select "button", text: /Enable fulfilment\s+2/
    assert_select "button", text: /Disable fulfilment\s+2/

    post enable_search_fulfilment_connections_store_path(@store), params: { search: "Canvas Art Print" }
    assert_redirected_to connections_store_path(@store, search: "Canvas Art Print")

    assert matching.reload.fulfilment_active
    assert matching_variant.reload.fulfilment_active
    assert by_variant.reload.fulfilment_active
    assert variant_match.reload.fulfilment_active
    assert removed_variant.reload.fulfilment_active
    assert_not other.reload.fulfilment_active
    assert_not other_variant.reload.fulfilment_active

    post disable_search_fulfilment_connections_store_path(@store), params: { search: "Canvas Art Print" }
    assert_not matching.reload.fulfilment_active
    assert_not matching_variant.reload.fulfilment_active
    assert_not by_variant.reload.fulfilment_active
    assert removed_variant.reload.fulfilment_active
    assert_not other.reload.fulfilment_active
  end

  test "fulfilment search actions require a search" do
    post enable_search_fulfilment_connections_store_path(@store)
    assert_redirected_to connections_store_path(@store)
    assert_equal "Search for products before changing fulfilment.", flash[:alert]
  end

  private

  def capture_sql
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
