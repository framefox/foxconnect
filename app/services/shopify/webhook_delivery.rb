module Shopify
  # The database owns retry timing. Redis only transports the current attempt.
  module WebhookDelivery
    MAX_ATTEMPTS = 5
    LEASE = 30.minutes
    TOPIC_KINDS = {
      "fulfillment_orders/fulfillment_request_submitted" => "FULFILLMENT_REQUEST",
      "fulfillment_orders/cancellation_request_submitted" => "CANCELLATION_REQUEST"
    }.freeze
    TOPICS = [ "orders/create", "fulfillment_order_notification", *TOPIC_KINDS.keys ].freeze

    def self.enqueue(log)
      log.with_lock do
        return if log.delivery_terminal? || (log.next_attempt_at && log.next_attempt_at > Time.current)
        if log.delivery_attempts >= MAX_ATTEMPTS
          log.update!(delivery_state: "needs_review", delivery_job_id: nil, next_attempt_at: nil)
          return
        end
        store = log.store || Store.find_by(shopify_domain: log.shop_domain)
        unless store&.active?
          log.update!(delivery_state: "completed", processed_at: Time.current, status_code: 200)
          return
        end
        payload = log.payload
        raise ArgumentError, "Expected an object payload" unless payload.is_a?(Hash)
        job = if log.topic == "orders/create"
          raise ArgumentError, "Missing order ID" if payload["id"].blank?
          log.delivery_subject_id = payload.fetch("id").to_s
          ShopifyOrderImportJob.new(store.id, payload.fetch("id"), log.id)
        else
          kind = TOPIC_KINDS[log.topic] || payload.fetch("kind")
          raise ArgumentError, "Unknown fulfillment notification" unless TOPIC_KINDS.value?(kind)
          ShopifyFulfillmentRequestJob.new(store.id, kind, log.id)
        end
        # Persist ownership before enqueue. A failed enqueue is recovered after
        # the lease expires; an older queued job cannot execute the replacement.
        log.update!(delivery_state: "queued", delivery_job_id: job.job_id, next_attempt_at: LEASE.from_now)
        job.enqueue
      end
    rescue KeyError, ArgumentError => error
      log.update!(delivery_state: "needs_review", error_message: "Invalid webhook: #{error.message}", status_code: 422,
        delivery_job_id: nil, next_attempt_at: nil)
    end
  end
end
