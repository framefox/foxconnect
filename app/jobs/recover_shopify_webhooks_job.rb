class RecoverShopifyWebhooksJob < ApplicationJob
  queue_as :default

  TOPIC_KINDS = {
    "fulfillment_orders/fulfillment_request_submitted" => "FULFILLMENT_REQUEST",
    "fulfillment_orders/cancellation_request_submitted" => "CANCELLATION_REQUEST"
  }.freeze

  # Recover the gap between committing receipt and enqueueing in Redis, worker
  # restarts, and exhausted retries. Jobs serialize and deduplicate by log ID.
  def perform
    WebhookLog.where(processed_at: nil, status_code: [ 0, 202, 500 ])
      .where(topic: [ "orders/create", "fulfillment_order_notification", *TOPIC_KINDS.keys ])
      .where("updated_at < ?", 10.minutes.ago).order(:updated_at).limit(100).each do |log|
      log.with_lock do
        next if log.processed_at? || log.updated_at > 10.minutes.ago
        store = Store.find_by(shopify_domain: log.shop_domain)
        unless store&.active?
          log.update!(processed_at: Time.current, status_code: 200)
          next
        end
        if log.topic == "orders/create"
          ShopifyOrderImportJob.perform_later(store.id, log.payload.fetch("id"), log.id)
        else
          kind = TOPIC_KINDS[log.topic] || log.payload.fetch("kind")
          ShopifyFulfillmentRequestJob.perform_later(store.id, kind, log.id)
        end
        log.update!(status_code: 202, updated_at: Time.current)
      end
    end
  end
end
