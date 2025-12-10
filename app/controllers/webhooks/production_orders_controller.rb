module Webhooks
  # Handles webhooks from FRAMEFOX PRODUCTION STORES (internal system)
  # Does NOT require HMAC verification
  class ProductionOrdersController < ApplicationController
    skip_before_action :verify_authenticity_token

    def paid
      webhook_data = JSON.parse(request.body.read)

      # Find the order by shopify_remote_order_id (not scoped to webhook store)
      order_id = webhook_data["id"]
      order = Order.find_by(shopify_remote_order_id: order_id.to_s)

      unless order
        # Return 200 to acknowledge receipt - order may not exist in our system yet or may not be a FoxConnect order
        Rails.logger.info "Order payment webhook: Order not found for shopify_remote_order_id: #{order_id} (ignoring)"
        render json: { message: "Order not found - acknowledged" }, status: :ok
        return
      end

      # Check if payment has already been captured (idempotency)
      if order.payment_captured?
        Rails.logger.info "Order payment already captured: #{order.id} (shopify_remote_order_id: #{order.shopify_remote_order_id})"
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

        Rails.logger.info "Order payment captured: #{order.id} (shopify_remote_order_id: #{order.shopify_remote_order_id})"
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
  end
end
