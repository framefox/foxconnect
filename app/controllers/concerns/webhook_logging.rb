module WebhookLogging
  extend ActiveSupport::Concern

  included do
    around_action :log_webhook_request
  end

  private

  def log_webhook_request
    start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    @webhook_log = nil

    # Read and store the request body for logging
    # This needs to happen before any other processing
    request.body.rewind
    raw_body = request.body.read
    request.body.rewind

    # Extract Shopify headers
    shopify_headers = extract_shopify_headers

    webhook_id = shopify_headers["X-Shopify-Webhook-Id"]
    attributes = {
      topic: shopify_headers["X-Shopify-Topic"] || extract_topic_from_path,
      shop_domain: shopify_headers["X-Shopify-Shop-Domain"],
      headers: shopify_headers, payload: raw_body, status_code: 0,
      store: Store.find_by(shopify_domain: shopify_headers["X-Shopify-Shop-Domain"])
    }
    @webhook_log = if webhook_id.present?
      WebhookLog.create_or_find_by!(webhook_id: webhook_id) { |log| log.assign_attributes(attributes) }
    else
      WebhookLog.create!(attributes)
    end

    # Serialize duplicate deliveries. A failed attempt must remain retryable.
    @webhook_log.with_lock do
      if @webhook_log.success?
        head :ok
      else
        @webhook_log.update!(error_message: nil)
        yield
        @webhook_log.processed_at = Time.current if response.status.between?(200, 299) && response.status != 202
        @webhook_log.update!(status_code: response.status,
          processing_time_ms: ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time) * 1000).round)
      end
    end
  rescue StandardError => e
    @webhook_log&.update!(status_code: 500, error_message: "#{e.class}: #{e.message}")
    raise
  end

  def extract_shopify_headers
    {
      "X-Shopify-Topic" => (request.headers["X-Shopify-Topic"] || request.headers["Shopify-Topic"]),
      "X-Shopify-Shop-Domain" => (request.headers["X-Shopify-Shop-Domain"] || request.headers["Shopify-Shop-Domain"]),
      "X-Shopify-Webhook-Id" => (request.headers["X-Shopify-Webhook-Id"] || request.headers["Shopify-Webhook-Id"]),
      "X-Shopify-API-Version" => (request.headers["X-Shopify-API-Version"] || request.headers["Shopify-API-Version"]),
      "X-Shopify-Hmac-Sha256" => (request.headers["X-Shopify-Hmac-Sha256"] || request.headers["Shopify-Hmac-Sha256"]).present? ? "[REDACTED]" : nil,
      "X-Shopify-Shop-ID" => (request.headers["X-Shopify-Shop-ID"] || request.headers["Shopify-Shop-ID"])
    }.compact
  end

  def extract_topic_from_path
    # Extract topic from request path like /webhooks/orders/create -> "orders/create"
    path = request.path.sub(%r{^/webhooks/}, "")
    path.presence || "unknown"
  end

  # Helper method for controllers to update the webhook log with additional error info
  def update_webhook_log_error(message)
    @webhook_log&.update!(error_message: message)
  end
end
