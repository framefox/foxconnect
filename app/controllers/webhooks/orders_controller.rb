module Webhooks
  class OrdersController < ApplicationController
    include ShopifyWebhookVerification
    include WebhookLogging

    def create
      store = find_store_by_webhook_headers
      return if performed?
      payload = JSON.parse(request.raw_post)
      raise ArgumentError, "Missing order ID" if payload["id"].blank?
      Shopify::WebhookDelivery.enqueue(@webhook_log)
      head :accepted
    rescue JSON::ParserError, ArgumentError
      head :bad_request
    end
  end
end
