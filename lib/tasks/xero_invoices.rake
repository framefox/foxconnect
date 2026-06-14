namespace :xero do
  desc "Deprecated: per-order Xero invoices are now created during production submission"
  task create_invoices: :environment do
    puts "xero:create_invoices is deprecated."
    puts "Per-order Xero invoices are created when orders are submitted to production."
    puts "Use xero:send_weekly_statements to email weekly statements and margin reports."
  end

  desc "Email weekly customer statements for per-order Xero invoices"
  task send_weekly_statements: :environment do
    unless Time.current.in_time_zone("Auckland").monday?
      puts "Skipping: today is not Monday in NZT."
      next
    end

    statement_runs = WeeklyStatementService.new.call
    puts "Sent #{statement_runs.size} weekly statement(s)."
  end

  desc "Backfill public Xero online invoice URLs for already-invoiced orders and statement line items"
  task backfill_online_invoice_urls: :environment do
    services = {}

    orders = Order.where.not(xero_invoice_id: [ nil, "" ])
      .where(xero_online_invoice_url: [ nil, "" ])

    puts "Backfilling online invoice URLs for #{orders.count} order(s)..."
    updated = 0
    skipped = 0
    failed = 0

    orders.find_each do |order|
      country = order.country_code
      if country.blank?
        puts "  Order ##{order.id}: no country_code — skipping"
        skipped += 1
        next
      end

      service = (services[country] ||= XeroService.new(country))
      url = service.get_online_invoice_url(order.xero_invoice_id)

      if url.present?
        order.update_columns(xero_online_invoice_url: url, updated_at: Time.current)
        updated += 1
        puts "  Order ##{order.id}: #{url}"
      else
        skipped += 1
        puts "  Order ##{order.id}: no online URL returned by Xero"
      end
    rescue => e
      failed += 1
      puts "  Order ##{order.id}: ERROR — #{e.message}"
    end

    line_items = StatementRunLineItem.where(xero_online_invoice_url: [ nil, "" ]).includes(:order)
    propagated = 0

    line_items.find_each do |line_item|
      next if line_item.order&.xero_online_invoice_url.blank?

      line_item.update_columns(
        xero_online_invoice_url: line_item.order.xero_online_invoice_url,
        updated_at: Time.current
      )
      propagated += 1
    end

    puts "Done. Orders updated: #{updated}, skipped: #{skipped}, failed: #{failed}. Statement line items updated: #{propagated}."
  end

  desc "Email invoice margin report CSV for an InvoiceRun (ID=<invoice_run_id>)"
  task send_margin_report: :environment do
    id = ENV.fetch("ID") { abort "Usage: rake xero:send_margin_report ID=<invoice_run_id>" }

    invoice_run = InvoiceRun.find_by(id: id)
    abort "InvoiceRun not found with ID: #{id}" unless invoice_run

    send_margin_report_email(invoice_run)
  end
end

def send_margin_report_email(invoice_run)
  company = invoice_run.company
  customer_emails = company.shopify_customers.joins(:user).pluck("users.email").compact.uniq

  if customer_emails.empty?
    puts "    No customer emails found for #{company.company_name} — skipping margin report email"
    return
  end

  puts "    Emailing margin report to: #{customer_emails.join(', ')} (CC: george@framefox.co.nz)"
  InvoiceMailer.invoice_margin_report(invoice_run: invoice_run).deliver_now
  puts "    Sent!"
end
