namespace :orders do
  desc "Find payment-pending orders across remote Shopify stores and email a summary"
  task pending_payments: :environment do
    stores_data = []

    CountryConfig.supported_countries.each do |country_code|
      config = CountryConfig.for_country(country_code)
      shop = config["shopify_domain"]
      token = config["shopify_access_token"]
      admin_url = config["shopify_remote_store"]
      country_name = config["country_name"]

      unless shop.present? && token.present?
        puts "Skipping #{country_code}: missing Shopify credentials"
        next
      end

      puts "Querying #{country_name} (#{shop})..."

      session = ShopifyAPI::Auth::Session.new(shop: shop, access_token: token)
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

      orders = []
      cursor = nil

      loop do
        response = client.query(query: pending_orders_query, variables: { cursor: cursor })

        if response.nil? || response.body.dig("data", "orders").nil?
          puts "  Error querying #{country_name}: #{response&.body&.dig("errors") || "no response"}"
          break
        end

        edges = response.body.dig("data", "orders", "edges") || []
        edges.each do |edge|
          node = edge["node"]
          company_data = node.dig("purchasingEntity", "company")

          orders << {
            name: node["name"],
            id: extract_numeric_id(node["id"]),
            company_name: company_data&.dig("name"),
            company_id: company_data ? extract_numeric_id(company_data["id"]) : nil,
            total_price: node.dig("totalPriceSet", "shopMoney", "amount"),
            currency: node.dig("totalPriceSet", "shopMoney", "currencyCode")
          }
        end

        has_next = response.body.dig("data", "orders", "pageInfo", "hasNextPage")
        break unless has_next

        cursor = edges.last["cursor"]
      end

      puts "  Found #{orders.size} pending payment order(s)"

      companies = orders.group_by { |o| o[:company_id] || "none" }.map do |_key, company_orders|
        first = company_orders.first
        {
          company_name: first[:company_name],
          company_id: first[:company_id],
          order_count: company_orders.size,
          total_value: company_orders.sum { |o| o[:total_price].to_f },
          currency: first[:currency]
        }
      end.sort_by { |c| -c[:total_value] }

      stores_data << {
        country_code: country_code,
        country_name: country_name,
        shopify_admin_url: admin_url,
        order_count: orders.size,
        companies: companies
      }
    end

    total = stores_data.sum { |s| s[:order_count] }

    if total > 0
      AdminMailer.pending_payment_orders(stores_data: stores_data).deliver_now
      puts "\nEmailed report with #{total} pending payment order(s) to george@framefox.co.nz"
    else
      puts "\nNo pending payment orders found across any store."
    end
  end
end

def pending_orders_query
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
            displayFinancialStatus
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

def extract_numeric_id(gid)
  gid.to_s.split("/").last
end
