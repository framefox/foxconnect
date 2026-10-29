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
