class ShopifyWebhookJob < ApplicationJob
  queue_as :default
  self.enqueue_after_transaction_commit = true
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  private

  def process_delivery(webhook_log_id)
    log = WebhookLog.find(webhook_log_id)
    Shopify::Lock.with(:delivery, log.id) do
      log.reload
      return if log.processed_at?
      yield
      log.update!(processed_at: Time.current, status_code: 200, error_message: nil)
    end
  rescue StandardError => error
    log&.update!(status_code: 500, error_message: "#{error.class}: #{error.message}")
    raise
  end
end
