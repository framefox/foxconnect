module Webhooks
  class FulfillmentOrderNotificationsController < ApplicationController
    include ShopifyWebhookVerification
    include WebhookLogging

    TOPIC_KINDS = {
      "fulfillment_orders/fulfillment_request_submitted" => "FULFILLMENT_REQUEST",
      "fulfillment_orders/cancellation_request_submitted" => "CANCELLATION_REQUEST"
    }.freeze

    def create
      store = find_store_by_webhook_headers
      return if performed?
      payload = JSON.parse(request.raw_post)
      topic = (request.headers["X-Shopify-Topic"] || request.headers["Shopify-Topic"]) || request.path.delete_prefix("/webhooks/")
      kind = TOPIC_KINDS[topic] || payload["kind"]
      unless TOPIC_KINDS.value?(kind)
        head :bad_request
        return
      end
      Shopify::WebhookDelivery.enqueue(@webhook_log)
      head :accepted
    rescue JSON::ParserError
      head :bad_request
    end
  end
end
