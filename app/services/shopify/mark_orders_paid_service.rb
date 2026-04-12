module Shopify
  class MarkOrdersPaidService
    attr_reader :invoice_run

    def initialize(invoice_run:)
      @invoice_run = invoice_run
    end

    def call
      config = CountryConfig.for_country(invoice_run.country_code)
      shop = config&.dig("shopify_domain")
      token = config&.dig("shopify_access_token")

      unless shop.present? && token.present?
        Rails.logger.error "MarkOrdersPaidService: missing Shopify credentials for #{invoice_run.country_code}"
        return { successes: [], failures: [{ error: "Missing Shopify credentials for #{invoice_run.country_code}" }] }
      end

      session = ShopifyAPI::Auth::Session.new(shop: shop, access_token: token)
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

      results = { successes: [], failures: [] }

      invoice_run.invoice_run_line_items.find_each do |line_item|
        order_gid = "gid://shopify/Order/#{line_item.shopify_order_id}"

        begin
          response = client.query(query: MARK_AS_PAID_MUTATION, variables: { input: { id: order_gid } })

          if response.nil?
            results[:failures] << { order_name: line_item.shopify_order_name, error: "No response from Shopify" }
            next
          end

          data = response.body.dig("data", "orderMarkAsPaid")
          user_errors = data&.dig("userErrors") || []

          if user_errors.any?
            error_messages = user_errors.map { |e| e["message"] }.join(", ")
            results[:failures] << { order_name: line_item.shopify_order_name, error: error_messages }
            Rails.logger.warn "MarkOrdersPaidService: #{line_item.shopify_order_name} failed: #{error_messages}"
          else
            results[:successes] << { order_name: line_item.shopify_order_name, order_gid: order_gid }
            Rails.logger.info "MarkOrdersPaidService: #{line_item.shopify_order_name} marked as paid"
          end
        rescue => e
          results[:failures] << { order_name: line_item.shopify_order_name, error: e.message }
          Rails.logger.error "MarkOrdersPaidService: #{line_item.shopify_order_name} exception: #{e.message}"
        end
      end

      Rails.logger.info "MarkOrdersPaidService: completed for InvoiceRun ##{invoice_run.id} — " \
                        "#{results[:successes].size} succeeded, #{results[:failures].size} failed"
      results
    end

    private

    MARK_AS_PAID_MUTATION = <<~GRAPHQL
      mutation OrderMarkAsPaid($input: OrderMarkAsPaidInput!) {
        orderMarkAsPaid(input: $input) {
          order {
            id
            name
            displayFinancialStatus
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end
end
