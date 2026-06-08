require "test_helper"

class WeeklyStatementServiceTest < ActiveSupport::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  test "creates and emails statement for last week's invoiced orders only" do
    company, user = create_company_with_customer!
    included_order = create_invoiced_order!(
      user: user,
      xero_invoice_id: "included-xero-id",
      xero_invoice_number: "INV-INCLUDED",
      xero_invoiced_at: auckland_time("2026-06-10 12:00")
    )
    excluded_order = create_invoiced_order!(
      user: user,
      xero_invoice_id: "excluded-xero-id",
      xero_invoice_number: "INV-EXCLUDED",
      xero_invoiced_at: auckland_time("2026-06-02 12:00")
    )

    statement_runs = WeeklyStatementService.new(reference_date: Date.new(2026, 6, 15)).call

    assert_equal 1, statement_runs.size
    statement_run = statement_runs.first
    assert_equal company, statement_run.company
    assert_equal Date.new(2026, 6, 8), statement_run.period_start_on
    assert_equal Date.new(2026, 6, 14), statement_run.period_end_on
    assert_equal "sent", statement_run.status
    assert_equal [ included_order.id ], statement_run.statement_run_line_items.pluck(:order_id)
    assert_not_includes statement_run.statement_run_line_items.pluck(:order_id), excluded_order.id

    assert_equal 1, ActionMailer::Base.deliveries.size
    email = ActionMailer::Base.deliveries.last
    attachment_names = email.attachments.map(&:filename)

    assert attachment_names.any? { |name| name.start_with?("statement_") }
    assert attachment_names.any? { |name| name.start_with?("invoice_margin_report_") }
    assert_includes email.attachments.find { |attachment| attachment.filename.start_with?("statement_") }.body.decoded, "INV-INCLUDED"
    assert_includes email.attachments.find { |attachment| attachment.filename.start_with?("invoice_margin_report_") }.body.decoded, "gross_margin_percentage"
  end

  private

  def create_company_with_customer!
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Statement Test #{suffix}")
    user = User.create!(
      email: "statement-#{suffix}@example.com",
      organization: organization,
      country: "NZ"
    )
    company = Company.create!(
      company_name: "Statement Company #{suffix}",
      shopify_company_id: "company-#{suffix}",
      shopify_company_location_id: "location-#{suffix}",
      shopify_company_contact_id: "contact-#{suffix}",
      country_code: "NZ",
      xero_contact_id: "xero-contact-#{suffix}"
    )
    ShopifyCustomer.create!(
      user: user,
      company: company,
      external_shopify_id: rand(1_000_000..9_999_999),
      country_code: "NZ"
    )

    [ company, user ]
  end

  def create_invoiced_order!(user:, xero_invoice_id:, xero_invoice_number:, xero_invoiced_at:)
    suffix = SecureRandom.hex(6)
    order = Order.create!(
      user: user,
      organization: user.organization,
      external_id: "statement-order-#{suffix}",
      external_number: "STORE-#{suffix}",
      currency: "NZD",
      fulfillment_currency: "NZD",
      country_code: "NZ",
      shopify_remote_order_id: "remote-#{suffix}",
      shopify_remote_order_name: "#3001",
      in_production_at: auckland_time("2026-06-09 10:00"),
      subtotal_price_cents: 20_000,
      total_discounts_cents: 0,
      total_shipping_cents: 2_000,
      total_tax_cents: 2_869,
      total_price_cents: 22_000,
      production_subtotal_cents: 12_000,
      production_shipping_cents: 1_500,
      production_total_cents: 13_500,
      xero_invoice_id: xero_invoice_id,
      xero_invoice_number: xero_invoice_number,
      xero_invoice_url: "https://go.xero.com/AccountsReceivable/View.aspx?InvoiceID=#{xero_invoice_id}",
      xero_invoice_due_date: Date.new(2026, 6, 22),
      xero_invoiced_at: xero_invoiced_at
    )
    order.create_shipping_address!(name: "Statement Recipient", address1: "1 Test Street", city: "Auckland", country: "New Zealand", country_code: "NZ")
    order
  end

  def auckland_time(value)
    Time.find_zone!("Auckland").parse(value)
  end
end
