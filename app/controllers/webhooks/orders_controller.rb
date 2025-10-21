module Webhooks
  class OrdersController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_webhook

    def paid
      webhook_data = JSON.parse(request.body.read)

      # Find the order by shopify_remote_order_id
      order_id = webhook_data["id"]
      order = Order.find_by(shopify_remote_order_id: order_id.to_s)

      unless order
        Rails.logger.warn "Order payment webhook: Order not found for shopify_remote_order_id: #{order_id}"
        render json: { error: "Order not found" }, status: :not_found
        return
      end

      # Check if payment has already been captured (idempotency)
      if order.payment_captured?
        Rails.logger.info "Order payment already captured: #{order.id} (shopify_remote_order_id: #{order_id})"
        render json: { message: "Payment already captured" }, status: :ok
        return
      end

      # Mark the order as paid
      if order.mark_payment_captured!
        # Log the payment activity
        order.log_activity(
          activity_type: "payment",
          title: "Payment Captured",
          description: "Order payment was captured in Shopify",
          metadata: {
            financial_status: webhook_data["financial_status"],
            total_price: webhook_data["total_price"],
            currency: webhook_data["currency"],
            payment_gateway_names: webhook_data["payment_gateway_names"]
          },
          occurred_at: Time.current
        )

        Rails.logger.info "Order payment captured: #{order.id} (shopify_remote_order_id: #{order_id})"
        render json: { message: "Payment captured successfully", order_id: order.id }, status: :ok
      else
        Rails.logger.error "Failed to mark payment as captured for order: #{order.id}"
        render json: { error: "Failed to capture payment" }, status: :unprocessable_entity
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in order payment webhook: #{e.message}"
      render json: { error: "Invalid JSON" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Order payment webhook error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Internal server error" }, status: :internal_server_error
    end

    private

    def verify_shopify_webhook
      # TODO: Implement proper Shopify webhook verification using HMAC
      # For now, we'll just log that verification should be implemented
      Rails.logger.info "Shopify webhook verification should be implemented"

      # You can implement verification like this:
      # hmac_header = request.headers['X-Shopify-Hmac-Sha256']
      # data = request.body.read
      # verified = verify_webhook(data, hmac_header)
      #
      # unless verified
      #   render json: { error: 'Unauthorized' }, status: :unauthorized
      # end
    end
  end
end
