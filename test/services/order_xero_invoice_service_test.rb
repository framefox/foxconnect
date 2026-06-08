require "test_helper"

class OrderXeroInvoiceServiceTest < ActiveSupport::TestCase
  class FakeXeroService
    attr_reader :payload, :called

    def initialize(result: default_result, error: nil)
      @result = result
      @error = error
      @called = false
    end

    def create_invoice(**payload)
      @called = true
      @payload = payload
      raise @error if @error

      @result
    end

    private

    def default_result
      {
        invoice_id: "xero-invoice-id",
        invoice_number: "INV-1001",
        invoice_url: "https://go.xero.com/AccountsReceivable/View.aspx?InvoiceID=xero-invoice-id"
      }
    end
  end

  test "calculates due date as seven days after the next statement delivery time" do
    order = create_order!(in_production_at: auckland_time("2026-06-08 07:59"))
    assert_equal Date.new(2026, 6, 15), OrderXeroInvoiceService.new(order: order).due_date

    order.update!(in_production_at: auckland_time("2026-06-08 08:00"))
    assert_equal Date.new(2026, 6, 22), OrderXeroInvoiceService.new(order: order).due_date

    order.update!(in_production_at: auckland_time("2026-06-08 08:01"))
    assert_equal Date.new(2026, 6, 22), OrderXeroInvoiceService.new(order: order).due_date

    order.update!(in_production_at: auckland_time("2026-06-09 10:00"))
    assert_equal Date.new(2026, 6, 22), OrderXeroInvoiceService.new(order: order).due_date

    order.update!(in_production_at: auckland_time("2026-06-14 10:00"))
    assert_equal Date.new(2026, 6, 22), OrderXeroInvoiceService.new(order: order).due_date
  end

  test "calculates due date from the Auckland date at timezone boundaries" do
    order = create_order!(in_production_at: Time.utc(2026, 6, 7, 13, 30))

    assert_equal Date.new(2026, 6, 15), OrderXeroInvoiceService.new(order: order).due_date
  end

  test "builds NZ product and shipping lines with separate account codes" do
    order = create_order!(
      country_code: "NZ",
      currency: "NZD",
      production_subtotal_cents: 12_000,
      production_shipping_cents: 1_500,
      production_total_cents: 13_500
    )
    create_order_item!(order: order, variant_title: "A3 Black Frame", production_cost_cents: 7_000)
    create_order_item!(order: order, variant_title: "A4 Oak Frame", production_cost_cents: 5_000)

    line_items = OrderXeroInvoiceService.new(order: order).build_line_items

    assert_equal 3, line_items.size
    assert_equal "A3 Black Frame", line_items.first[:description]
    assert_equal "SH-20000", line_items.first[:account_code]
    assert_equal 70.0, line_items.first[:unit_amount]
    assert_equal "A4 Oak Frame", line_items.second[:description]
    assert_equal "SH-20000", line_items.second[:account_code]
    assert_equal 50.0, line_items.second[:unit_amount]
    assert_equal "SH-20002", line_items.third[:account_code]
    assert_equal 15.0, line_items.third[:unit_amount]
  end

  test "builds AU product and shipping lines with AU account codes" do
    order = create_order!(
      country_code: "AU",
      currency: "AUD",
      production_subtotal_cents: 20_000,
      production_shipping_cents: 2_000,
      production_total_cents: 22_000
    )
    create_order_item!(order: order, variant_title: "A2 Walnut Frame", production_cost_cents: 20_000)

    line_items = OrderXeroInvoiceService.new(order: order).build_line_items

    assert_equal [ "SH-20000-A", "SH-20002-A" ], line_items.map { |line| line[:account_code] }
  end

  test "omits shipping line when shipping amount is zero" do
    order = create_order!(production_shipping_cents: 0, production_total_cents: 12_000)

    line_items = OrderXeroInvoiceService.new(order: order).build_line_items

    assert_equal 1, line_items.size
    assert_equal "SH-20000", line_items.first[:account_code]
  end

  test "allocates product subtotal across itemized product lines when item costs do not exactly match subtotal" do
    order = create_order!(production_subtotal_cents: 10_001, production_shipping_cents: 0, production_total_cents: 10_001)
    create_order_item!(order: order, variant_title: "Large Print", production_cost_cents: 6_000)
    create_order_item!(order: order, variant_title: "Small Print", production_cost_cents: 4_000)

    line_items = OrderXeroInvoiceService.new(order: order).build_line_items

    assert_equal [ "Large Print", "Small Print" ], line_items.map { |line| line[:description] }
    assert_equal 100.01, line_items.sum { |line| line[:unit_amount] }.round(2)
  end

  test "creates authorised invoice and saves Xero reference on the order" do
    order = create_order!(in_production_at: auckland_time("2026-06-09 10:00"))
    fake_xero = FakeXeroService.new

    result = OrderXeroInvoiceService.new(order: order, xero_service: fake_xero).call

    assert result[:success]
    assert fake_xero.called
    assert_equal "AUTHORISED", fake_xero.payload[:status]
    assert_equal "NZD", fake_xero.payload[:currency]
    assert_equal "foxconnect-order-xero-invoice-test-#{order.id}", fake_xero.payload[:idempotency_key]
    assert_equal Date.new(2026, 6, 22), fake_xero.payload[:due_date]

    order.reload
    assert_equal "xero-invoice-id", order.xero_invoice_id
    assert_equal "INV-1001", order.xero_invoice_number
    assert_equal Date.new(2026, 6, 22), order.xero_invoice_due_date
    assert_not_nil order.xero_invoiced_at
    assert_nil order.xero_invoice_error
  end

  test "skips when order already has a Xero invoice" do
    order = create_order!(xero_invoice_id: "existing-xero-id")
    fake_xero = FakeXeroService.new

    result = OrderXeroInvoiceService.new(order: order, xero_service: fake_xero).call

    assert result[:success]
    assert result[:skipped]
    assert_not fake_xero.called
  end

  test "persists error without raising by default" do
    order = create_order!
    fake_xero = FakeXeroService.new(error: XeroService::XeroError.new("Xero unavailable"))

    result = OrderXeroInvoiceService.new(order: order, xero_service: fake_xero).call

    assert_not result[:success]
    assert_equal "Xero unavailable", order.reload.xero_invoice_error
    assert_nil order.xero_invoice_id
  end

  private

  def create_order!(attributes = {})
    country_code = attributes[:country_code] || "NZ"
    currency = attributes[:currency] || (country_code == "AU" ? "AUD" : "NZD")
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Xero Invoice Test #{suffix}")
    user = User.create!(
      email: "xero-invoice-#{suffix}@example.com",
      organization: organization,
      country: country_code
    )
    company = Company.create!(
      company_name: "Xero Company #{suffix}",
      shopify_company_id: "company-#{suffix}",
      shopify_company_location_id: "location-#{suffix}",
      shopify_company_contact_id: "contact-#{suffix}",
      country_code: country_code,
      xero_contact_id: "xero-contact-#{suffix}"
    )
    ShopifyCustomer.create!(
      user: user,
      company: company,
      external_shopify_id: rand(1_000_000..9_999_999),
      country_code: country_code
    )

    order = Order.create!({
      user: user,
      organization: organization,
      external_id: "order-#{suffix}",
      external_number: "STORE-#{suffix}",
      currency: currency,
      fulfillment_currency: currency,
      country_code: country_code,
      shopify_remote_order_id: "remote-#{suffix}",
      shopify_remote_order_name: "#1001",
      in_production_at: auckland_time("2026-06-08 10:00"),
      subtotal_price_cents: 20_000,
      total_discounts_cents: 0,
      total_shipping_cents: 2_000,
      total_tax_cents: 2_869,
      total_price_cents: 22_000,
      production_subtotal_cents: 12_000,
      production_shipping_cents: 1_500,
      production_total_cents: 13_500
    }.merge(attributes))

    order.create_shipping_address!(name: "Test Recipient", address1: "1 Test Street", city: "Auckland", country: "New Zealand", country_code: country_code)
    order
  end

  def create_order_item!(order:, variant_title:, production_cost_cents:, quantity: 1)
    order.order_items.create!(
      is_custom: true,
      variant_title: variant_title,
      quantity: quantity,
      requires_shipping: true,
      production_cost_cents: production_cost_cents
    )
  end

  def auckland_time(value)
    Time.find_zone!("Auckland").parse(value)
  end
end
