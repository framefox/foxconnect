class ShopifyWebhookJob < ApplicationJob
  queue_as :default
  self.enqueue_after_transaction_commit = true
  # Retry timing and limits live on WebhookLog, including across worker restarts.
  sidekiq_options retry: false

  private

  def process_delivery(webhook_log_id)
    log = WebhookLog.find_by(id: webhook_log_id)
    return unless log

    Shopify::Lock.with(:delivery, log.id) do
      log.reload
      return if log.delivery_terminal?
      if log.delivery_job_id.present?
        return unless log.delivery_job_id == job_id
      else
        # Compatibility with jobs enqueued before delivery ownership existed.
        return if log.next_attempt_at && log.next_attempt_at > Time.current
      end
      if log.delivery_attempts >= Shopify::WebhookDelivery::MAX_ATTEMPTS
        log.update!(delivery_state: "needs_review", next_attempt_at: nil, delivery_job_id: nil)
        return
      end
      log.update!(delivery_state: "processing", delivery_job_id: job_id,
        delivery_attempts: log.delivery_attempts + 1, next_attempt_at: Shopify::WebhookDelivery::LEASE.from_now)
      begin
        log.update!(error_message: nil)
        yield
        log.reload.update!(processed_at: Time.current, status_code: 200, delivery_state: "completed",
          delivery_job_id: nil, next_attempt_at: nil)
      rescue StandardError => error
        permanent = error.is_a?(ImportOrderService::OrderUnavailable)
        exhausted = log.delivery_attempts >= Shopify::WebhookDelivery::MAX_ATTEMPTS
        log.update!(delivery_state: permanent || exhausted ? "needs_review" : "retry_wait",
          status_code: 500, error_message: "#{error.class}: #{error.message}", delivery_job_id: nil,
          next_attempt_at: permanent || exhausted ? nil : (2**log.delivery_attempts).minutes.from_now)
        Rails.logger.warn "Webhook #{log.id}: #{log.delivery_state} after #{log.delivery_attempts} attempts (#{error.class})"
      end
    end
  end
end
