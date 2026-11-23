require "test_helper"

class Admin::StoresControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    org = Organization.create!(name: "Country settings test")
    @admin = User.create!(email: "country-admin-#{SecureRandom.hex(5)}@example.com", password: "password123",
      admin: true, organization: org, country: "NZ")
    @owner = User.create!(email: "country-owner-#{SecureRandom.hex(5)}@example.com", organization: org, country: "NZ")
    @store = Store.create!(organization: org, created_by_user: @owner, name: "Country settings", platform: "shopify",
      shopify_domain: "country-settings-#{SecureRandom.hex(5)}.myshopify.com", shopify_token: "token", access_scopes: "read_orders")
  end

  test "admin can select both countries and clear the selection" do
    sign_in @admin, scope: :user
    get edit_admin_store_path(@store)
    assert_response :success
    assert_select "input#store_fulfilment_country_NZ[checked]"
    assert_select "input#store_fulfilment_country_AU:not([checked])"

    patch admin_store_path(@store), params: { store: { enabled_fulfilment_countries: ["", "NZ", "AU"] } }
    assert_redirected_to admin_stores_path
    assert_equal %w[NZ AU], @store.reload.enabled_fulfilment_countries
    assert_equal "NZ", @owner.reload.country

    patch admin_store_path(@store), params: { store: { enabled_fulfilment_countries: [""] } }
    assert_redirected_to admin_stores_path
    assert_empty @store.reload.enabled_fulfilment_countries
  end

  test "invalid country is rejected without changing saved permissions" do
    sign_in @admin, scope: :user
    patch admin_store_path(@store), params: { store: { enabled_fulfilment_countries: ["US"] } }
    assert_response :unprocessable_entity
    assert_equal ["NZ"], @store.reload.enabled_fulfilment_countries
    assert_includes response.body, "must contain only NZ or AU"
  end

  test "non admin cannot enable a destination through either settings endpoint" do
    sign_in @owner, scope: :user
    patch admin_store_path(@store), params: { store: { enabled_fulfilment_countries: %w[NZ AU] } }
    assert_redirected_to root_path
    assert_equal ["NZ"], @store.reload.enabled_fulfilment_countries
    patch update_settings_connections_store_path(@store), params: { store: { enabled_fulfilment_countries: %w[NZ AU] } }
    assert_equal ["NZ"], @store.reload.enabled_fulfilment_countries
  end
end
