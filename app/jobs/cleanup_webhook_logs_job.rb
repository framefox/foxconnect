class CleanupWebhookLogsJob < ApplicationJob
  queue_as :default

  def perform
    deleted_count = WebhookLog.cleanup_old_records!(days: 30)
    Rails.logger.info "CleanupWebhookLogsJob: Cleaned up #{deleted_count} old webhook logs"
  end
end
