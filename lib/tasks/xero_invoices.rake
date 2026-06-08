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
