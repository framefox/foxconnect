namespace :xero do
  desc "Create draft Xero invoices for pending-payment Shopify orders (company-driven)"
  task create_invoices: :environment do
    companies = Company.xero_enabled.where.not(country_code: [ nil, "" ])
    if companies.none?
      puts "No companies with xero_contact_id configured. Nothing to do."
      next
    end

    puts "Found #{companies.count} Xero-enabled company/ies"

    companies_by_country = companies.group_by(&:country_code)
    already_invoiced_order_ids = InvoiceRunLineItem.pluck(:shopify_order_id).to_set

    companies_by_country.each do |country_code, country_companies|
      config = CountryConfig.for_country(country_code)
      shop = config["shopify_domain"]
      token = config["shopify_access_token"]
      currency = config["currency"]
      country_name = config["country_name"]

      unless shop.present? && token.present?
        puts "Skipping #{country_code}: missing Shopify credentials"
        next
      end

      puts "\n--- #{country_name} ---"

      company_lookup = country_companies.index_by(&:shopify_company_id)

      session = ShopifyAPI::Auth::Session.new(shop: shop, access_token: token)
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

      all_orders = fetch_all_pending_orders(client, country_name)
      puts "  Found #{all_orders.size} total pending payment order(s)"

      xero_service = nil

      country_companies.each do |company|
        company_orders = all_orders.select { |o| o[:company_id] == company.shopify_company_id }

        if company_orders.empty?
          puts "\n  #{company.company_name}: no pending orders"
          next
        end

        new_orders = company_orders.reject { |o| already_invoiced_order_ids.include?(o[:id]) }

        if new_orders.empty?
          puts "\n  #{company.company_name}: all #{company_orders.size} order(s) already invoiced"
          next
        end

        puts "\n  #{company.company_name}: #{new_orders.size} new order(s) to invoice"

        remote_order_ids = new_orders.map { |o| o[:id] }
        local_orders = Order.includes(:shipping_address).where(shopify_remote_order_id: remote_order_ids).index_by(&:shopify_remote_order_id)

        line_items = new_orders.map do |order|
          local_order = local_orders[order[:id]]
          order_ref = if local_order&.external_number.present?
            local_order.external_number
          elsif local_order
            recipient = local_order.shipping_address&.full_name
            "Custom: #{recipient} - #{local_order.uid}".strip
          else
            order[:name]
          end
          description = "#{order_ref} (#{local_order&.shopify_remote_order_name || order[:name]})"

          {
            description: description,
            quantity: 1,
            unit_amount: order[:total_price].to_f
          }
        end

        total_cents = new_orders.sum { |o| (o[:total_price].to_f * 100).round }

        begin
          xero_service ||= XeroService.new(country_code)

          result = xero_service.create_draft_invoice(
            contact_id: company.xero_contact_id,
            line_items: line_items,
            date: Date.today,
            due_date: Date.today + 7.days
          )

          invoice_run = InvoiceRun.create!(
            company: company,
            country_code: country_code,
            xero_invoice_id: result[:invoice_id],
            xero_invoice_number: result[:invoice_number],
            xero_invoice_url: result[:invoice_url],
            total_amount_cents: total_cents,
            currency: currency,
            status: "draft",
            invoice_date: Date.today
          )

          new_orders.each do |order|
            invoice_run.invoice_run_line_items.create!(
              shopify_order_id: order[:id],
              shopify_order_name: order[:name],
              amount_cents: (order[:total_price].to_f * 100).round,
              currency: currency
            )
            already_invoiced_order_ids.add(order[:id])
          end

          puts "    Created draft invoice #{result[:invoice_number]} with #{new_orders.size} line item(s)"
          puts "    Total: #{currency} #{'%.2f' % (total_cents / 100.0)}"
          puts "    Xero: #{result[:invoice_url]}"

          send_margin_report_email(invoice_run)
        rescue XeroService::XeroError => e
          puts "    ERROR creating Xero invoice: #{e.message}"
        rescue ActiveRecord::RecordInvalid => e
          puts "    ERROR saving invoice run: #{e.message}"
        end
      end
    end

    puts "\nDone."
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

def fetch_all_pending_orders(client, country_name)
  orders = []
  cursor = nil

  loop do
    response = client.query(
      query: xero_pending_orders_query,
      variables: { cursor: cursor }
    )

    if response.nil? || response.body.dig("data", "orders").nil?
      puts "  Error querying #{country_name}: #{response&.body&.dig("errors") || "no response"}"
      break
    end

    edges = response.body.dig("data", "orders", "edges") || []
    edges.each do |edge|
      node = edge["node"]
      company_data = node.dig("purchasingEntity", "company")

      next unless company_data

      orders << {
        name: node["name"],
        id: node["id"].to_s.split("/").last,
        company_id: company_data["id"].to_s.split("/").last,
        total_price: node.dig("totalPriceSet", "shopMoney", "amount"),
        currency: node.dig("totalPriceSet", "shopMoney", "currencyCode")
      }
    end

    has_next = response.body.dig("data", "orders", "pageInfo", "hasNextPage")
    break unless has_next

    cursor = edges.last["cursor"]
  end

  orders
end

def xero_pending_orders_query
  <<~GRAPHQL
    query PendingPaymentOrders($cursor: String) {
      orders(first: 50, after: $cursor, query: "financial_status:pending") {
        edges {
          node {
            id
            name
            totalPriceSet {
              shopMoney {
                amount
                currencyCode
              }
            }
            purchasingEntity {
              ... on PurchasingCompany {
                company {
                  id
                  name
                }
              }
            }
          }
          cursor
        }
        pageInfo {
          hasNextPage
        }
      }
    }
  GRAPHQL
end
