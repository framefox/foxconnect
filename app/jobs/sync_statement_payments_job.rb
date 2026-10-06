class SyncStatementPaymentsJob < ApplicationJob
  queue_as :default

  retry_on XeroService::XeroError, wait: 10.minutes, attempts: 3

  def perform
    SyncStatementPaymentsService.new.call
  end
end
