module Shopify
  class MarkOrdersPaidService
    attr_reader :source

    # Accepts either an InvoiceRun (invoice_run:) or a StatementRun (statement_run:).
    # Both expose a #country_code and a collection of line items responding to
    # #shopify_order_id / #shopify_order_name.
    def initialize(invoice_run: nil, statement_run: nil)
      @source = invoice_run || statement_run
      raise ArgumentError, "must provide invoice_run or statement_run" if @source.nil?
    end

    def call
      config = CountryConfig.for_country(source.country_code)
      shop = config&.dig("shopify_domain")
      token = config&.dig("shopify_access_token")

      unless shop.present? && token.present?
        Rails.logger.error "MarkOrdersPaidService: missing Shopify credentials for #{source.country_code}"
        return { successes: [], failures: [{ error: "Missing Shopify credentials for #{source.country_code}" }] }
      end

      session = ShopifyAPI::Auth::Session.new(shop: shop, access_token: token)
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

      results = { successes: [], failures: [] }

      line_items.find_each do |line_item|
        if line_item.shopify_order_id.blank?
          results[:failures] << { order_name: line_item.shopify_order_name, error: "Missing Shopify order id" }
          Rails.logger.warn "MarkOrdersPaidService: skipping #{line_item.shopify_order_name} — missing Shopify order id"
          next
        end

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

      Rails.logger.info "MarkOrdersPaidService: completed for #{source.class.name} ##{source.id} — " \
                        "#{results[:successes].size} succeeded, #{results[:failures].size} failed"
      results
    end

    private

    def line_items
      if source.respond_to?(:invoice_run_line_items)
        source.invoice_run_line_items
      else
        source.statement_run_line_items
      end
    end

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
