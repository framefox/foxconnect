class MarkStatementRunOrdersPaidJob < ApplicationJob
  queue_as :default

  def perform(statement_run)
    Rails.logger.info "Starting MarkStatementRunOrdersPaidJob for StatementRun ##{statement_run.id}"

    service = Shopify::MarkOrdersPaidService.new(statement_run: statement_run)
    result = service.call

    Rails.logger.info(
      "MarkStatementRunOrdersPaidJob completed for StatementRun ##{statement_run.id}: " \
      "#{result[:successes].size} succeeded, #{result[:failures].size} failed"
    )
  rescue => e
    Rails.logger.error "MarkStatementRunOrdersPaidJob failed for StatementRun ##{statement_run.id}: #{e.message}"
    raise e
  end
end
