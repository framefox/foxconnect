require "test_helper"

class SyncStatementPaymentsServiceTest < ActiveSupport::TestCase
  test "marks paid Xero invoices in Shopify and archives the statement when every invoice is paid" do
    statement = create_statement!(status: "sent")
    paid = add_invoice!(statement, invoice_id: "paid-invoice", order_name: "#1001")
    also_paid = add_invoice!(statement, invoice_id: "also-paid", order_name: "#1002")
    marked = []

    result = SyncStatementPaymentsService.new(
      xero_client_for: xero_client("paid-invoice" => "PAID", "also-paid" => "PAID"),
      shopify_marker: lambda { |statement_run:, line_items:|
        assert_equal statement, statement_run
        marked.concat(line_items.map(&:id))
        { successes: line_items.map { |item| { line_item: item } }, failures: [] }
      }
    ).call

    assert_equal [ paid.id, also_paid.id ].sort, marked.sort
    assert_equal 2, result[:invoices_checked]
    assert_equal 2, result[:orders_marked_paid]
    assert_equal 1, result[:statements_archived]
    assert_equal "archived", statement.reload.status
    assert paid.reload.payment_sync_complete?
    assert also_paid.reload.payment_sync_complete?
  end

  test "leaves the statement open when only some invoices are paid in Xero" do
    statement = create_statement!(status: "sent")
    paid = add_invoice!(statement, invoice_id: "paid-invoice", order_name: "#1001")
    unpaid = add_invoice!(statement, invoice_id: "unpaid-invoice", order_name: "#1002")
    marked = []

    result = SyncStatementPaymentsService.new(
      xero_client_for: xero_client("paid-invoice" => "PAID", "unpaid-invoice" => "AUTHORISED"),
      shopify_marker: lambda { |statement_run:, line_items:|
        assert_equal [ paid.id ], line_items.map(&:id)
        marked.concat(line_items.map(&:id))
        { successes: line_items.map { |item| { line_item: item } }, failures: [] }
      }
    ).call

    assert_equal [ paid.id ], marked
    assert_equal "sent", statement.reload.status
    assert paid.reload.shopify_marked_paid?
    assert_not unpaid.reload.xero_paid?
    assert_equal 0, result[:statements_archived]
  end

  test "retries the Shopify update without querying Xero again once the invoice is known to be paid" do
    statement = create_statement!(status: "sent")
    paid = add_invoice!(statement, invoice_id: "paid-invoice", order_name: "#1001", xero_paid_at: Time.current)
    xero_called = false

    SyncStatementPaymentsService.new(
      xero_client_for: lambda { |_country|
        xero_called = true
        raise "Xero should not be queried"
      },
      shopify_marker: lambda { |statement_run:, line_items:|
        assert_equal [ paid.id ], line_items.map(&:id)
        { successes: line_items.map { |item| { line_item: item } }, failures: [] }
      }
    ).call

    assert_not xero_called
    assert_equal "archived", statement.reload.status
    assert paid.reload.shopify_marked_paid?
  end

  test "does not archive when Shopify rejects the order and records the error" do
    statement = create_statement!(status: "sent")
    paid = add_invoice!(statement, invoice_id: "paid-invoice", order_name: "#1001")

    result = SyncStatementPaymentsService.new(
      xero_client_for: xero_client("paid-invoice" => "PAID"),
      shopify_marker: lambda { |statement_run:, line_items:|
        { successes: [], failures: [ { line_item: line_items.first, error: "Order is cancelled" } ] }
      }
    ).call

    assert_equal "sent", statement.reload.status
    assert paid.reload.xero_paid?
    assert_not paid.shopify_marked_paid?
    assert_equal "Order is cancelled", paid.shopify_paid_error
    assert_equal 1, result[:failures].size
    assert_equal 0, result[:statements_archived]
  end

  test "skips archived statements" do
    statement = create_statement!(status: "archived")
    add_invoice!(statement, invoice_id: "paid-invoice", order_name: "#1001")

    result = SyncStatementPaymentsService.new(
      xero_client_for: lambda { |_country| flunk "should not query Xero" },
      shopify_marker: lambda { |**| flunk "should not mark Shopify" }
    ).call

    assert_equal 0, result[:invoices_checked]
    assert_equal "archived", statement.reload.status
  end

  test "archives a statement whose invoices were already synced" do
    statement = create_statement!(status: "sent")
    add_invoice!(
      statement,
      invoice_id: "paid-invoice",
      order_name: "#1001",
      xero_paid_at: Time.current,
      shopify_marked_paid_at: Time.current
    )

    result = SyncStatementPaymentsService.new(
      xero_client_for: lambda { |_country| flunk "should not query Xero" },
      shopify_marker: lambda { |**| flunk "should not mark Shopify" }
    ).call

    assert_equal "archived", statement.reload.status
    assert_equal 1, result[:statements_archived]
    assert_equal 0, result[:orders_marked_paid]
  end

  test "raises when Xero is unavailable and leaves the statement open" do
    statement = create_statement!(status: "sent")
    add_invoice!(statement, invoice_id: "paid-invoice", order_name: "#1001")
    xero = Class.new do
      def get_invoices(_ids)
        raise XeroService::XeroError, "down"
      end
    end.new

    error = assert_raises(XeroService::XeroError) do
      SyncStatementPaymentsService.new(
        xero_client_for: ->(_country) { xero },
        shopify_marker: ->(**) { flunk "should not mark Shopify" }
      ).call
    end

    assert_equal "down", error.message
    assert_equal "sent", statement.reload.status
    assert_nil statement.statement_run_line_items.first.xero_paid_at
  end

  test "checks every open statement invoice in one Xero request per country" do
    first = create_statement!(status: "pending")
    second = create_statement!(status: "sent")
    add_invoice!(first, invoice_id: "first-invoice", order_name: "#1001")
    add_invoice!(second, invoice_id: "second-invoice", order_name: "#1002")
    requested = []

    SyncStatementPaymentsService.new(
      xero_client_for: xero_client({ "first-invoice" => "AUTHORISED", "second-invoice" => "AUTHORISED" }, requested),
      shopify_marker: ->(**) { flunk "should not mark Shopify" }
    ).call

    assert_equal [ [ "first-invoice", "second-invoice" ] ], requested.map(&:sort)
  end

  private

  def xero_client(statuses, requested = [])
    client = Class.new do
      def initialize(statuses, requested)
        @statuses = statuses
        @requested = requested
      end

      def get_invoices(ids)
        @requested << ids
        ids.filter_map do |id|
          status = @statuses[id]
          next if status.nil?

          { "InvoiceID" => id, "Status" => status }
        end
      end
    end.new(statuses, requested)

    ->(_country) { client }
  end

  def create_statement!(status:)
    suffix = SecureRandom.hex(6)
    company = Company.create!(
      company_name: "Statement Company #{suffix}",
      shopify_company_id: "company-#{suffix}",
      shopify_company_location_id: "location-#{suffix}",
      shopify_company_contact_id: "contact-#{suffix}",
      country_code: "NZ",
      xero_contact_id: "xero-contact-#{suffix}"
    )

    StatementRun.create!(
      company: company,
      country_code: "NZ",
      period_start_on: Date.new(2026, 6, 8),
      period_end_on: Date.new(2026, 6, 14),
      total_amount_cents: 13_500,
      currency: "NZD",
      status: status,
      sent_at: status == "pending" ? nil : Time.current
    )
  end

  def add_invoice!(statement, invoice_id:, order_name:, xero_paid_at: nil, shopify_marked_paid_at: nil)
    suffix = SecureRandom.hex(6)
    organization = Organization.create!(name: "Statement Org #{suffix}")
    user = User.create!(
      email: "statement-#{suffix}@example.com",
      organization: organization,
      country: "NZ"
    )
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
      production_total_cents: 13_500,
      xero_invoice_id: invoice_id,
      xero_invoice_number: invoice_id,
      xero_invoiced_at: Time.find_zone!("Auckland").parse("2026-06-10 12:00")
    )

    statement.statement_run_line_items.create!(
      order: order,
      shopify_order_id: order.shopify_remote_order_id,
      shopify_order_name: order_name,
      xero_invoice_id: invoice_id,
      xero_invoice_number: invoice_id,
      xero_invoice_url: "https://go.xero.com/AccountsReceivable/View.aspx?InvoiceID=#{invoice_id}",
      product_amount_cents: 12_000,
      shipping_amount_cents: 1_500,
      amount_cents: 13_500,
      currency: "NZD",
      invoiced_at: order.xero_invoiced_at,
      xero_paid_at: xero_paid_at,
      shopify_marked_paid_at: shopify_marked_paid_at
    )
  end
end
