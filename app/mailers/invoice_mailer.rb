class InvoiceMailer < ApplicationMailer
  ADMIN_EMAIL = "george@framefox.co.nz"

  def invoice_margin_report(invoice_run:)
    @invoice_run = invoice_run
    @company = invoice_run.company

    customer_emails = @company.shopify_customers
      .joins(:user)
      .pluck("users.email")
      .compact
      .uniq

    return if customer_emails.empty?

    attachments[csv_filename] = {
      mime_type: "text/csv",
      content: generate_csv(invoice_run)
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

  private

  def csv_filename
    company_slug = @company.company_name.parameterize
    invoice_num = @invoice_run.xero_invoice_number&.parameterize || "draft"
    "invoice_margin_report_#{company_slug}_#{invoice_num}_#{@invoice_run.invoice_date.iso8601}.csv"
  end

  def generate_csv(invoice_run)
    order_ids = invoice_run.invoice_run_line_items.pluck(:shopify_order_id)
    orders = Order.includes(:shipping_address)
      .where(shopify_remote_order_id: order_ids)
      .order(:created_at)

    CSV.generate do |csv|
      csv << %w[
        order_date
        external_number
        shopify_order_name
        framefox_subtotal
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

      orders.find_each do |order|
        is_custom = order.external_number.blank?

        order_label = if is_custom
          recipient = order.shipping_address&.full_name
          "Custom: #{recipient} - #{order.uid}".strip
        else
          order.external_number
        end

        if is_custom
          csv << [
            order.created_at.to_date.iso8601,
            order_label,
            order.shopify_remote_order_name,
            order.production_subtotal.to_f,
            order.production_shipping.to_f,
            order.production_total.to_f,
            nil, nil, nil, nil, nil, nil, nil, nil
          ]
        else
          fc = order.fulfillment_currency || order.currency

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
