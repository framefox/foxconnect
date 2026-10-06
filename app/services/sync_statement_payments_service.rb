class SyncStatementPaymentsService
  def initialize(xero_client_for: nil, shopify_marker: nil)
    @xero_client_for = xero_client_for || method(:default_xero_client)
    @shopify_marker = shopify_marker || method(:default_shopify_marker)
    @xero_clients = {}
  end

  def call
    result = { invoices_checked: 0, orders_marked_paid: 0, statements_archived: 0, failures: [] }
    statements = StatementRun.active.includes(:statement_run_line_items).to_a
    return result if statements.empty?

    errors = record_xero_payments!(statements, result)

    statements.each do |statement|
      mark_shopify_orders!(statement, result)
      archive_if_settled!(statement, result)
    end

    log_summary(result)
    raise errors.first if errors.any?

    result
  end

  private

  # Archive only after every invoice is paid in Xero and each Shopify order has
  # been marked paid. This job only visits statements that are not archived, so
  # a failed Shopify update has to stay on an open statement to be retried.
  def record_xero_payments!(statements, result)
    pending_by_country = Hash.new { |groups, country| groups[country] = [] }

    statements.each do |statement|
      statement.statement_run_line_items.each do |line_item|
        next if line_item.xero_paid?

        pending_by_country[statement.country_code] << line_item
      end
    end

    errors = []
    pending_by_country.each do |country_code, line_items|
      mark_paid_invoices!(country_code, line_items, result)
    rescue XeroService::XeroError => e
      errors << e
      result[:failures] << { country_code: country_code, error: e.message }
      Rails.logger.error "SyncStatementPaymentsService: Xero lookup failed for #{country_code}: #{e.message}"
    end
    errors
  end

  def mark_paid_invoices!(country_code, line_items, result)
    invoice_ids = line_items.map(&:xero_invoice_id).uniq
    invoices = xero_client_for(country_code).get_invoices(invoice_ids)
    result[:invoices_checked] += invoice_ids.size

    statuses = invoices.each_with_object({}) do |invoice, map|
      map[invoice["InvoiceID"].to_s.downcase] = invoice["Status"].to_s.upcase
    end

    line_items.each do |line_item|
      status = statuses[line_item.xero_invoice_id.to_s.downcase]
      if status.nil?
        Rails.logger.warn "SyncStatementPaymentsService: Xero did not return invoice #{line_item.xero_invoice_id}"
        next
      end
      next unless status == "PAID"

      line_item.update!(xero_paid_at: Time.current, shopify_paid_error: nil)
    end
  end

  def mark_shopify_orders!(statement, result)
    line_items = statement.statement_run_line_items.select { |item| item.xero_paid? && !item.shopify_marked_paid? }
    return if line_items.empty?

    marker_result = @shopify_marker.call(statement_run: statement, line_items: line_items) || { successes: [], failures: [] }
    succeeded_ids = Array(marker_result[:successes]).filter_map { |entry| entry[:line_item]&.id || entry[:line_item_id] }.to_set
    failures = Array(marker_result[:failures])

    line_items.each do |line_item|
      if succeeded_ids.include?(line_item.id)
        line_item.update!(shopify_marked_paid_at: Time.current, shopify_paid_error: nil)
        result[:orders_marked_paid] += 1
        next
      end

      message = failure_message_for(failures, line_item)
      next if message.blank?

      line_item.update!(shopify_paid_error: message.truncate(1000))
      result[:failures] << { statement_run_id: statement.id, order_name: line_item.shopify_order_name, error: message }
    end
  end

  def failure_message_for(failures, line_item)
    match = failures.find { |failure| (failure[:line_item]&.id || failure[:line_item_id]) == line_item.id }
    return match[:error].to_s if match

    generic = failures.find { |failure| failure[:line_item].nil? && failure[:line_item_id].nil? }
    generic&.dig(:error).to_s
  end

  def archive_if_settled!(statement, result)
    items = statement.statement_run_line_items.reload
    return if items.empty?
    return unless items.all?(&:payment_sync_complete?)

    statement.update!(status: "archived")
    result[:statements_archived] += 1
    Rails.logger.info "SyncStatementPaymentsService: archived StatementRun ##{statement.id}"
  end

  def xero_client_for(country_code)
    @xero_client_for.call(country_code)
  end

  def default_xero_client(country_code)
    @xero_clients[country_code] ||= XeroService.new(country_code)
  end

  def default_shopify_marker(statement_run:, line_items:)
    Shopify::MarkOrdersPaidService.new(statement_run: statement_run, line_items: line_items).call
  end

  def log_summary(result)
    Rails.logger.info(
      "SyncStatementPaymentsService: checked #{result[:invoices_checked]} invoice(s), " \
      "marked #{result[:orders_marked_paid]} Shopify order(s) paid, " \
      "archived #{result[:statements_archived]} statement(s), " \
      "#{result[:failures].size} failure(s)"
    )
  end
end
