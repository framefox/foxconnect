require "sidekiq/api"

class RecoverShopifyWebhooksJob < ApplicationJob
  queue_as :default

  def perform
    queued_ids = queued_job_ids
    WebhookLog.where(processed_at: nil, status_code: [ 0, 202, 500 ])
      .where(topic: Shopify::WebhookDelivery::TOPICS)
      .where(delivery_state: %w[pending queued processing retry_wait])
      .where("next_attempt_at <= :now OR (next_attempt_at IS NULL AND updated_at < :stale)", now: Time.current, stale: 10.minutes.ago)
      .order(:updated_at).limit(100).each do |log|
      next if log.delivery_job_id.present? && queued_ids.include?(log.delivery_job_id)
      # Never replace a running attempt, even if its lease has expired.
      Shopify::Lock.try_with(:delivery, log.id) { Shopify::WebhookDelivery.enqueue(log) }
    end
  end

  private

  def queued_job_ids
    # Snapshot once per recovery pass rather than scanning Redis for each event.
    return Set.new unless self.class.queue_adapter.is_a?(ActiveJob::QueueAdapters::SidekiqAdapter)

    Sidekiq::Queue.new("default").each_with_object(Set.new) do |job, ids|
      ids << job.item.dig("args", 0, "job_id")
    end
  end
end
