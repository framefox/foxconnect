require "csv"

class InvoiceMailer < ApplicationMailer
  ADMIN_EMAIL = "george@framefox.co.nz"

  # Activity emails respect each user's notification subscription preference.
  default NotificationSubscriptionInterceptor::ACTIVITY_HEADER => "true"

  def invoice_margin_report(invoice_run:)
    @invoice_run = invoice_run
    @company = invoice_run.company
    orders = orders_for_invoice_run(invoice_run)

    customer_emails = recipient_emails(@company)

    return if customer_emails.empty?

    attachments[legacy_margin_csv_filename] = {
      mime_type: "text/csv",
      content: generate_margin_csv(orders)
    }

    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    country_config = CountryConfig.for_country(invoice_run.country_code)
    from_email = country_config&.dig("email_from") || "frames@framefox.co.nz"

    mail(
      to: customer_emails,
      cc: ADMIN_EMAIL,
      from: format_from_email(from_email),
      subject: "Invoice Margin Report: #{@invoice_run.xero_invoice_number} - #{@company.company_name} - #{@invoice_run.invoice_date.strftime('%d %b %Y')}"
    )
  end

  def weekly_statement(statement_run:)
    @statement_run = statement_run
    @company = statement_run.company
    @line_items = statement_run.statement_run_line_items.includes(order: :shipping_address).order(:invoiced_at)
    @orders = @line_items.map(&:order)

    customer_emails = recipient_emails(@company)
    return if customer_emails.empty?

    attachments[statement_csv_filename] = {
      mime_type: "text/csv",
      content: generate_statement_csv(statement_run)
    }

    attachments[margin_csv_filename] = {
      mime_type: "text/csv",
      content: generate_margin_csv(@orders)
    }

    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    country_config = CountryConfig.for_country(statement_run.country_code)
    from_email = country_config&.dig("email_from") || "frames@framefox.co.nz"

    mail(
      to: customer_emails,
      cc: ADMIN_EMAIL,
      from: format_from_email(from_email),
      subject: "Weekly Statement: #{@company.company_name} - #{@statement_run.period_label}"
    )
  end

  private

  def recipient_emails(company)
    company.shopify_customers
      .joins(:user)
      .pluck("users.email")
      .compact
      .uniq
  end

  def legacy_margin_csv_filename
    company_slug = @company.company_name.parameterize
    invoice_num = @invoice_run.xero_invoice_number&.parameterize || "draft"
    "invoice_margin_report_#{company_slug}_#{invoice_num}_#{@invoice_run.invoice_date.iso8601}.csv"
  end

  def statement_csv_filename
    company_slug = @company.company_name.parameterize
    "statement_#{company_slug}_#{@statement_run.period_start_on.iso8601}_#{@statement_run.period_end_on.iso8601}.csv"
  end

  def margin_csv_filename
    company_slug = @company.company_name.parameterize
    "invoice_margin_report_#{company_slug}_#{@statement_run.period_start_on.iso8601}_#{@statement_run.period_end_on.iso8601}.csv"
  end

  def orders_for_invoice_run(invoice_run)
    order_ids = invoice_run.invoice_run_line_items.pluck(:shopify_order_id)
    Order.includes(:shipping_address)
      .where(shopify_remote_order_id: order_ids)
      .order(:created_at)
  end

  def generate_statement_csv(statement_run)
    line_items = statement_run.statement_run_line_items.includes(order: :shipping_address).order(:invoiced_at)

    CSV.generate do |csv|
      csv << %w[
        xero_invoice_number
        order_reference
        shopify_order_name
        product_amount
        shipping_amount
        total
        currency
        invoice_date
        due_date
        xero_invoice_url
      ]

      line_items.each do |line_item|
        order = line_item.order

        csv << [
          line_item.xero_invoice_number,
          order.invoice_order_reference,
          line_item.shopify_order_name,
          line_item.product_amount,
          line_item.shipping_amount,
          line_item.amount,
          line_item.currency,
          line_item.invoiced_at&.to_date&.iso8601,
          line_item.invoice_due_date&.iso8601,
          line_item.xero_invoice_url
        ]
      end
    end
  end

  def generate_margin_csv(orders)
    CSV.generate do |csv|
      csv << %w[
        order_date
        external_number
        shopify_order_name
        framefox_subtotal
        framefox_subtotal_ex_gst
        framefox_shipping
        framefox_total
        framefox_total_ex_gst
        store_subtotal
        store_discounts
        store_shipping
        customer_paid
        customer_paid_ex_gst
        gross_margin
        gross_margin_percentage
      ]

      orders.each do |order|
        is_custom = order.external_number.blank?

        order_label = order.invoice_order_reference

        if is_custom
          csv << [
            order.created_at.to_date.iso8601,
            order_label,
            order.shopify_remote_order_name,
            order.production_subtotal.to_f,
            nil,
            order.production_shipping.to_f,
            order.production_total.to_f,
            nil, nil, nil, nil, nil, nil, nil, nil
          ]
        else
          fc = order.fulfillment_currency || order.currency

          subtotal_ex_gst_cents = (order.production_subtotal_cents / (1 + order.gst_rate)).round
          total_ex_gst_cents = (order.production_total_cents / (1 + order.gst_rate)).round

          revenue_cents = (order.subtotal_price_cents || 0) - (order.total_tax_cents || 0)
          margin_cents = revenue_cents - total_ex_gst_cents
          margin_pct = if revenue_cents > 0 && total_ex_gst_cents > 0
            ((revenue_cents - total_ex_gst_cents).to_f / revenue_cents * 100).round(1)
          end

          csv << [
            order.created_at.to_date.iso8601,
            order_label,
            order.shopify_remote_order_name,
            order.production_subtotal.to_f,
            Money.new(subtotal_ex_gst_cents, fc).to_f,
            order.production_shipping.to_f,
            order.production_total.to_f,
            Money.new(total_ex_gst_cents, fc).to_f,
            order.subtotal_price.to_f,
            order.total_discounts.to_f,
            order.total_shipping.to_f,
            order.total_price.to_f,
            (order.total_price - order.total_tax).to_f,
            Money.new(margin_cents, order.currency).to_f,
            margin_pct
          ]
        end
      end
    end
  end
end
