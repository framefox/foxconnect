class WeeklyStatementService
  attr_reader :reference_date

  def initialize(reference_date: nil)
    @reference_date = reference_date
  end

  def call
    statement_runs = send_pending_statements

    grouped_orders.each do |(company, country_code, currency), orders|
      next unless company
      next if customer_emails(company).empty?

      statement_runs << create_and_send_statement!(
        company: company,
        country_code: country_code,
        currency: currency,
        orders: orders
      )
    end

    statement_runs.compact
  end

  def period_start_on
    @period_start_on ||= current_week_start - 7
  end

  def period_end_on
    @period_end_on ||= current_week_start - 1
  end

  private

  def current_week_start
    @current_week_start ||= effective_reference_date.beginning_of_week(:monday)
  end

  def effective_reference_date
    date = reference_date || Time.current.in_time_zone(StatementDeliverySchedule::TIME_ZONE).to_date
    date.respond_to?(:to_date) ? date.to_date : Date.parse(date.to_s)
  end

  def grouped_orders
    orders_for_period.group_by { |order| [ order.xero_company, order.country_code, order.fulfillment_currency || order.currency ] }
  end

  def orders_for_period
    period_range = period_start_on.beginning_of_day..period_end_on.end_of_day
    already_statemented_order_ids = StatementRunLineItem.pluck(:order_id).to_set

    Order.includes(:shipping_address, :user, store: :user)
      .where(xero_invoiced_at: period_range)
      .where.not(xero_invoice_id: [ nil, "" ])
      .order(:xero_invoiced_at)
      .reject { |order| already_statemented_order_ids.include?(order.id) }
  end

  def create_and_send_statement!(company:, country_code:, currency:, orders:)
    statement_run = nil

    StatementRun.transaction do
      statement_run = StatementRun.create!(
        company: company,
        country_code: country_code,
        period_start_on: period_start_on,
        period_end_on: period_end_on,
        total_amount_cents: orders.sum(&:production_total_cents),
        currency: currency,
        status: "pending"
      )

      orders.each do |order|
        statement_run.statement_run_line_items.create!(
          order: order,
          shopify_order_id: order.shopify_remote_order_id,
          shopify_order_name: order.shopify_remote_order_name,
          xero_invoice_id: order.xero_invoice_id,
          xero_invoice_number: order.xero_invoice_number,
          xero_invoice_url: order.xero_invoice_url,
          product_amount_cents: order.production_subtotal_cents,
          shipping_amount_cents: order.production_shipping_cents,
          amount_cents: order.production_total_cents,
          currency: order.fulfillment_currency || order.currency,
          invoice_due_date: order.xero_invoice_due_date,
          invoiced_at: order.xero_invoiced_at
        )
      end
    end

    deliver_statement!(statement_run)
  end

  def customer_emails(company)
    company.shopify_customers
      .joins(:user)
      .pluck("users.email")
      .compact
      .uniq
  end

  def send_pending_statements
    StatementRun.pending.includes(:company).find_each.map do |statement_run|
      deliver_statement!(statement_run)
    end
  end

  def deliver_statement!(statement_run)
    InvoiceMailer.weekly_statement(statement_run: statement_run).deliver_now
    statement_run.update!(status: "sent", sent_at: Time.current)
    statement_run
  end
end
