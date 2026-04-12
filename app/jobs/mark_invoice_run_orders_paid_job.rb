class MarkInvoiceRunOrdersPaidJob < ApplicationJob
  queue_as :default

  def perform(invoice_run)
    Rails.logger.info "Starting MarkInvoiceRunOrdersPaidJob for InvoiceRun ##{invoice_run.id}"

    service = Shopify::MarkOrdersPaidService.new(invoice_run: invoice_run)
    result = service.call

    Rails.logger.info(
      "MarkInvoiceRunOrdersPaidJob completed for InvoiceRun ##{invoice_run.id}: " \
      "#{result[:successes].size} succeeded, #{result[:failures].size} failed"
    )
  rescue => e
    Rails.logger.error "MarkInvoiceRunOrdersPaidJob failed for InvoiceRun ##{invoice_run.id}: #{e.message}"
    raise e
  end
end
