require "test_helper"

class Admin::StatementRunsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test "show displays Xero and Shopify payment sync status for each invoice" do
    admin = create_admin!
    statement = create_statement!
    add_invoice!(statement, invoice_id: "awaiting", order_name: "#2001")
    add_invoice!(statement, invoice_id: "xero-paid", order_name: "#2002", xero_paid_at: Time.current, shopify_paid_error: "Order is cancelled")
    add_invoice!(statement, invoice_id: "shopify-paid", order_name: "#2003", xero_paid_at: Time.current, shopify_marked_paid_at: Time.current)

    sign_in admin, scope: :user
    get admin_statement_run_path(statement)

    assert_response :success
    assert_includes response.body, "Daily at 5:00am NZT"
    assert_includes response.body, "Awaiting Xero payment"
    assert_includes response.body, "Paid in Xero"
    assert_includes response.body, "Order is cancelled"
    assert_includes response.body, "Paid in Shopify"
    assert_includes response.body, "Mark All as Paid in Shopify"
  end

  private

  def create_admin!
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Admin Test #{suffix}")
    User.create!(
      email: "admin-statements-#{suffix}@example.com",
      password: "password123",
      admin: true,
      organization: organization,
      country: "NZ"
    )
  end

  def create_statement!
    suffix = SecureRandom.hex(6)
    company = Company.create!(
      company_name: "Statement Company #{suffix}",
      shopify_company_id: "company-#{suffix}",
      shopify_company_location_id: "location-#{suffix}",
      shopify_company_contact_id: "contact-#{suffix}",
      country_code: "NZ"
    )
    StatementRun.create!(
      company: company,
      country_code: "NZ",
      period_start_on: Date.new(2026, 6, 8),
      period_end_on: Date.new(2026, 6, 14),
      total_amount_cents: 13_500,
      currency: "NZD",
      status: "sent"
    )
  end

  def add_invoice!(statement, invoice_id:, order_name:, xero_paid_at: nil, shopify_marked_paid_at: nil, shopify_paid_error: nil)
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Statement Org #{suffix}")
    user = User.create!(email: "statement-#{suffix}@example.com", organization: organization, country: "NZ")
    order = Order.create!(
      user: user,
      organization: organization,
      external_id: "statement-order-#{suffix}",
      external_number: "STORE-#{suffix}",
      currency: "NZD",
      fulfillment_currency: "NZD",
      country_code: "NZ",
      shopify_remote_order_id: "remote-#{suffix}",
      shopify_remote_order_name: order_name,
      in_production_at: Time.find_zone!("Auckland").parse("2026-06-09 10:00"),
      subtotal_price_cents: 20_000,
      total_discounts_cents: 0,
      total_shipping_cents: 2_000,
      total_tax_cents: 2_869,
      total_price_cents: 22_000,
      production_subtotal_cents: 12_000,
      production_shipping_cents: 1_500,
      production_total_cents: 13_500
    )

    statement.statement_run_line_items.create!(
      order: order,
      shopify_order_id: order.shopify_remote_order_id,
      shopify_order_name: order_name,
      xero_invoice_id: invoice_id,
      xero_invoice_number: invoice_id,
      product_amount_cents: 12_000,
      shipping_amount_cents: 1_500,
      amount_cents: 13_500,
      currency: "NZD",
      xero_paid_at: xero_paid_at,
      shopify_marked_paid_at: shopify_marked_paid_at,
      shopify_paid_error: shopify_paid_error
    )
  end
end
