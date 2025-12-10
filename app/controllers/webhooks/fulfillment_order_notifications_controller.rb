module Webhooks
  # Handles fulfillment order notifications from Shopify
  # These are sent to the callback URL registered with the fulfillment service:
  # <callback_url>/fulfillment_order_notification
  #
  # Notification kinds:
  # - FULFILLMENT_REQUEST: Merchant clicked "Request fulfillment"
  # - CANCELLATION_REQUEST: Merchant requested to cancel fulfillment
  #
  # See: https://shopify.dev/docs/apps/build/orders-fulfillment/fulfillment-service-apps/build-for-fulfillment-services
  #
  class FulfillmentOrderNotificationsController < ApplicationController
    include ShopifyWebhookVerification

    before_action :find_store

    def create
      webhook_data = JSON.parse(request.body.read)
      kind = webhook_data["kind"]

      Rails.logger.info "Fulfillment order notification received: #{kind} for store: #{@store&.name}"
      Rails.logger.debug "Notification payload: #{webhook_data.inspect}"

      case kind
      when "FULFILLMENT_REQUEST"
        handle_fulfillment_request(webhook_data)
      when "CANCELLATION_REQUEST"
        handle_cancellation_request(webhook_data)
      else
        Rails.logger.warn "Unknown fulfillment order notification kind: #{kind}"
        render json: { message: "Unknown notification kind: #{kind}" }, status: :ok
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in fulfillment order notification: #{e.message}"
      render json: { error: "Invalid JSON" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Fulfillment order notification error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Internal server error" }, status: :internal_server_error
    end

    private

    def find_store
      @store = find_store_by_webhook_headers
    end

    # Handle merchant's request to fulfill an order
    # Auto-accept the request since we're always ready to fulfill (print-on-demand)
    def handle_fulfillment_request(webhook_data)
      # The notification doesn't include full fulfillment order data
      # We need to query assigned fulfillment orders to get details
      # For now, we auto-accept immediately

      Rails.logger.info "Processing fulfillment request for store: #{@store.name}"

      # Query and accept all pending fulfillment requests
      service = FulfillmentRequestHandlerService.new(@store)
      result = service.accept_pending_requests!

      if result[:success]
        render json: {
          message: "Fulfillment request accepted",
          accepted_count: result[:accepted_count]
        }, status: :ok
      else
        render json: {
          message: "Fulfillment request processed with errors",
          errors: result[:errors]
        }, status: :ok # Return 200 to acknowledge receipt
      end
    end

    # Handle merchant's request to cancel a fulfillment
    def handle_cancellation_request(webhook_data)
      Rails.logger.info "Processing cancellation request for store: #{@store.name}"

      # Query and accept all pending cancellation requests
      # Since we're print-on-demand, we can accept cancellations if not yet shipped
      service = FulfillmentRequestHandlerService.new(@store)
      result = service.accept_pending_cancellations!

      if result[:success]
        render json: {
          message: "Cancellation request processed",
          accepted_count: result[:accepted_count],
          rejected_count: result[:rejected_count]
        }, status: :ok
      else
        render json: {
          message: "Cancellation request processed with errors",
          errors: result[:errors]
        }, status: :ok # Return 200 to acknowledge receipt
      end
    end
  end
end

