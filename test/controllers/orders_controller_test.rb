require "test_helper"
require "minitest/mock"

class OrdersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "index excludes deleted stores while retaining manual and inactive store orders" do
    organization = Organization.create!(name: "Order visibility test")
    user = User.create!(email: "order-visibility@example.com", organization: organization, country: "NZ")
    active_store = create_store!(organization, "active", active: true)
    inactive_store = create_store!(organization, "inactive", active: false)
    deleted_store = create_store!(organization, "deleted", active: false, deleted_at: Time.current)
    active_order = create_order!(organization, "ACTIVE-ORDER", store: active_store)
    inactive_order = create_order!(organization, "INACTIVE-ORDER", store: inactive_store)
    manual_order = create_order!(organization, "MANUAL-ORDER", user: user)
    deleted_order = create_order!(organization, "DELETED-STORE-ORDER", store: deleted_store)
    skipped_order = create_order!(organization, "SKIPPED-ORDER", store: active_store, aasm_state: "skipped")
    other_organization = Organization.create!(name: "Other organization")
    other_order = create_order!(other_organization, "OTHER-ORG-ORDER")

    sign_in user, scope: :user
    CountryConfig.stub(:for_country, { "api_url" => "https://frame.example", "api_base_path" => "/api" }) do
      get orders_path
    end

    assert_response :success
    [active_order, inactive_order, manual_order].each do |order|
      assert_select "a[href='#{order_path(order)}']"
    end
    [deleted_order, skipped_order, other_order].each do |order|
      assert_select "a[href='#{order_path(order)}']", count: 0
    end
    assert Order.exists?(deleted_order.id), "Filtering must preserve historical records"
  end

  private

  def create_store!(organization, label, **attributes)
    Store.create!({ organization: organization, created_by_user: organization.users.first, name: label, platform: "shopify",
      shopify_domain: "visibility-#{label}.myshopify.com", shopify_token: "test-token",
      access_scopes: "read_orders" }.merge(attributes))
  end

  def create_order!(organization, name, **attributes)
    Order.create!({ organization: organization, name: name, external_id: name,
      currency: "NZD", country_code: "NZ", subtotal_price_cents: 0,
      total_discounts_cents: 0, total_shipping_cents: 0, total_tax_cents: 0,
      total_price_cents: 0, production_subtotal_cents: 0,
      production_shipping_cents: 0, production_total_cents: 0 }.merge(attributes))
  end
end
