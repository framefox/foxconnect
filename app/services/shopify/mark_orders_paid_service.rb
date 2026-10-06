module Shopify
  class MarkOrdersPaidService
    attr_reader :source

    SETTLED_FINANCIAL_STATUSES = %w[PAID PARTIALLY_REFUNDED REFUNDED].freeze

    # Accepts either an InvoiceRun (invoice_run:) or a StatementRun (statement_run:).
    # Both expose a #country_code and a collection of line items responding to
    # #shopify_order_id / #shopify_order_name.
    # Pass line_items: to mark a subset instead of every line on the source.
    def initialize(invoice_run: nil, statement_run: nil, line_items: nil)
      @source = invoice_run || statement_run
      @line_items_override = line_items
      raise ArgumentError, "must provide invoice_run or statement_run" if @source.nil?
    end

    def call
      config = CountryConfig.for_country(source.country_code)
      shop = config&.dig("shopify_domain")
      token = config&.dig("shopify_access_token")

      unless shop.present? && token.present?
        Rails.logger.error "MarkOrdersPaidService: missing Shopify credentials for #{source.country_code}"
        return { successes: [], failures: [ { error: "Missing Shopify credentials for #{source.country_code}" } ] }
      end

      session = ShopifyAPI::Auth::Session.new(shop: shop, access_token: token)
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

      results = { successes: [], failures: [] }

      each_line_item do |line_item|
        mark_line_item(client, line_item, results)
      end

      Rails.logger.info "MarkOrdersPaidService: completed for #{source.class.name} ##{source.id} — " \
                        "#{results[:successes].size} succeeded, #{results[:failures].size} failed"
      results
    end

    private

    def each_line_item
      items = line_items_for_run
      if items.is_a?(Array)
        items.each { |item| yield item }
      else
        items.find_each { |item| yield item }
      end
    end

    def line_items_for_run
      return @line_items_override unless @line_items_override.nil?

      if source.respond_to?(:invoice_run_line_items)
        source.invoice_run_line_items
      else
        source.statement_run_line_items
      end
    end

    def mark_line_item(client, line_item, results)
      if line_item.shopify_order_id.blank?
        record_failure(results, line_item, "Missing Shopify order id")
        Rails.logger.warn "MarkOrdersPaidService: skipping #{line_item.shopify_order_name} — missing Shopify order id"
        return
      end

      order_gid = "gid://shopify/Order/#{line_item.shopify_order_id}"

      begin
        response = client.query(query: MARK_AS_PAID_MUTATION, variables: { input: { id: order_gid } })

        if response.nil?
          record_failure(results, line_item, "No response from Shopify")
          return
        end

        data = response.body.dig("data", "orderMarkAsPaid")
        user_errors = data&.dig("userErrors") || []
        graphql_errors = response.body["errors"] || []

        if user_errors.any? || graphql_errors.any?
          error_messages = (user_errors + graphql_errors).map { |e| e["message"] }.join(", ")
          if settled_in_shopify?(client, order_gid)
            record_success(results, line_item, order_gid)
            Rails.logger.info "MarkOrdersPaidService: #{line_item.shopify_order_name} is already settled in Shopify"
          else
            record_failure(results, line_item, error_messages)
            Rails.logger.warn "MarkOrdersPaidService: #{line_item.shopify_order_name} failed: #{error_messages}"
          end
        else
          record_success(results, line_item, order_gid)
          Rails.logger.info "MarkOrdersPaidService: #{line_item.shopify_order_name} marked as paid"
        end
      rescue => e
        record_failure(results, line_item, e.message)
        Rails.logger.error "MarkOrdersPaidService: #{line_item.shopify_order_name} exception: #{e.message}"
      end
    end

    def settled_in_shopify?(client, order_gid)
      response = client.query(query: FINANCIAL_STATUS_QUERY, variables: { id: order_gid })
      status = response&.body&.dig("data", "order", "displayFinancialStatus")
      SETTLED_FINANCIAL_STATUSES.include?(status)
    rescue => e
      Rails.logger.error "MarkOrdersPaidService: financial status lookup failed for #{order_gid}: #{e.message}"
      false
    end

    def record_success(results, line_item, order_gid)
      results[:successes] << {
        order_name: line_item.shopify_order_name,
        order_gid: order_gid,
        line_item: line_item,
        line_item_id: line_item.id
      }
    end

    def record_failure(results, line_item, error)
      results[:failures] << {
        order_name: line_item.shopify_order_name,
        error: error,
        line_item: line_item,
        line_item_id: line_item.id
      }
    end

    FINANCIAL_STATUS_QUERY = <<~GRAPHQL
      query OrderFinancialStatus($id: ID!) {
        order(id: $id) {
          displayFinancialStatus
        }
      }
    GRAPHQL

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
