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

    # Create the log entry before processing, handling duplicate webhooks gracefully
    # Shopify may retry webhooks, sending the same webhook_id multiple times
    webhook_id = shopify_headers["X-Shopify-Webhook-Id"]

    if webhook_id.present?
      @webhook_log = WebhookLog.find_by(webhook_id: webhook_id)

      if @webhook_log
        # Duplicate webhook - already processed, return 200 to stop retries
        Rails.logger.info "[WebhookLogging] Duplicate webhook received: #{webhook_id}, returning early"
        head :ok
        return
      end
    end

    @webhook_log = WebhookLog.create!(
      topic: shopify_headers["X-Shopify-Topic"] || extract_topic_from_path,
      shop_domain: shopify_headers["X-Shopify-Shop-Domain"],
      webhook_id: webhook_id,
      headers: shopify_headers,
      payload: raw_body,
      status_code: 0  # Will be updated after processing
    )

    # Try to find and associate the store
    if @webhook_log.shop_domain.present?
      store = Store.find_by(shopify_domain: @webhook_log.shop_domain)
      @webhook_log.update!(store: store) if store
    end

    # Execute the controller action
    yield

    # Update with success status
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    processing_time = ((end_time - start_time) * 1000).round

    @webhook_log.update!(
      status_code: response.status,
      processing_time_ms: processing_time
    )
  rescue ActiveRecord::RecordNotUnique => e
    # Race condition: another request created the record between our find_by and create!
    # This is a duplicate webhook - return 200 to stop Shopify retries
    Rails.logger.info "[WebhookLogging] Duplicate webhook (race condition): #{e.message}"
    head :ok
  rescue StandardError => e
    # Update with error status if something went wrong
    end_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    processing_time = ((end_time - start_time) * 1000).round if start_time

    if @webhook_log
      @webhook_log.update!(
        status_code: response.status.presence || 500,
        error_message: "#{e.class}: #{e.message}",
        processing_time_ms: processing_time
      )
    end

    # Re-raise the exception so Rails can handle it normally
    raise
  end

  def extract_shopify_headers
    {
      "X-Shopify-Topic" => request.headers["X-Shopify-Topic"],
      "X-Shopify-Shop-Domain" => request.headers["X-Shopify-Shop-Domain"],
      "X-Shopify-Webhook-Id" => request.headers["X-Shopify-Webhook-Id"],
      "X-Shopify-API-Version" => request.headers["X-Shopify-API-Version"],
      "X-Shopify-Hmac-Sha256" => request.headers["X-Shopify-Hmac-Sha256"].present? ? "[REDACTED]" : nil,
      "X-Shopify-Shop-ID" => request.headers["X-Shopify-Shop-ID"]
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
