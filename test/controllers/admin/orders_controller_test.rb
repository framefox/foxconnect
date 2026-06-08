require "test_helper"

class Admin::OrdersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "show displays Xero invoice link for invoiced order" do
    admin = create_admin!
    order = create_invoiced_order!

    sign_in admin, scope: :user
    get admin_order_path(order)

    assert_response :success
    assert_includes response.body, "Open in Xero"
    assert_includes response.body, "INV-ADMIN"
    assert_includes response.body, order.xero_invoice_url
    assert_not_includes response.body, "Create Xero Invoice"
  end

  test "show displays create Xero invoice button for uninvoiced order" do
    admin = create_admin!
    order = create_uninvoiced_order!

    sign_in admin, scope: :user
    get admin_order_path(order)

    assert_response :success
    assert_includes response.body, "Create Xero Invoice"
    assert_includes response.body, retry_xero_invoice_admin_order_path(order)
  end

  private

  def create_admin!
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Admin Test #{suffix}")

    User.create!(
      email: "admin-orders-#{suffix}@example.com",
      password: "password123",
      admin: true,
      organization: organization,
      country: "NZ"
    )
  end

  def create_invoiced_order!
    create_order_with_xero_status!(
      xero_invoice_id: "admin-xero-id",
      xero_invoice_number: "INV-ADMIN",
      xero_invoice_url: "https://go.xero.com/AccountsReceivable/View.aspx?InvoiceID=admin-xero-id",
      xero_invoice_due_date: Date.new(2026, 6, 22),
      xero_invoiced_at: Time.find_zone!("Auckland").parse("2026-06-09 10:05")
    )
  end

  def create_uninvoiced_order!
    create_order_with_xero_status!
  end

  def create_order_with_xero_status!(xero_attributes = {})
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Admin Order Test #{suffix}")
    user = User.create!(
      email: "admin-order-owner-#{suffix}@example.com",
      organization: organization,
      country: "NZ"
    )
    order = Order.create!({
      user: user,
      organization: organization,
      external_id: "admin-order-#{suffix}",
      external_number: "STORE-#{suffix}",
      currency: "NZD",
      fulfillment_currency: "NZD",
      country_code: "NZ",
      aasm_state: "in_production",
      shopify_remote_order_id: "remote-#{suffix}",
      shopify_remote_order_name: "#4001",
      in_production_at: Time.find_zone!("Auckland").parse("2026-06-09 10:00"),
      subtotal_price_cents: 20_000,
      total_discounts_cents: 0,
      total_shipping_cents: 2_000,
      total_tax_cents: 2_869,
      total_price_cents: 22_000,
      production_subtotal_cents: 12_000,
      production_shipping_cents: 1_500,
      production_total_cents: 13_500
    }.merge(xero_attributes))
    order.create_shipping_address!(name: "Admin Recipient", address1: "1 Test Street", city: "Auckland", country: "New Zealand", country_code: "NZ")
    order
  end
end
