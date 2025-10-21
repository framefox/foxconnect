module Webhooks
  class OrdersController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_webhook
    before_action :find_store

    def create
      webhook_data = JSON.parse(request.body.read)
      order_id = webhook_data["id"]

      Rails.logger.info "Order create webhook received for order: #{order_id} from store: #{@store.name}"

      # Run ImportOrderService to import the order
      begin
        service = ImportOrderService.new(store: @store, order_id: order_id)
        order = service.call

        if order
          Rails.logger.info "Successfully imported order #{order.display_name} from webhook"
          render json: { message: "Order imported successfully", order_id: order.id }, status: :ok
        else
          Rails.logger.error "Failed to import order from webhook"
          render json: { error: "Failed to import order" }, status: :unprocessable_entity
        end
      rescue StandardError => e
        Rails.logger.error "Order create webhook error: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        render json: { error: "Internal server error: #{e.message}" }, status: :internal_server_error
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in order create webhook: #{e.message}"
      render json: { error: "Invalid JSON" }, status: :bad_request
    end

    def paid
      webhook_data = JSON.parse(request.body.read)

      # Find the order by shopify_remote_order_id scoped to the store
      order_id = webhook_data["id"]
      order = @store.orders.find_by(shopify_remote_order_id: order_id.to_s)

      unless order
        Rails.logger.warn "Order payment webhook: Order not found for shopify_remote_order_id: #{order_id} in store: #{@store.name}"
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
      # Verify HMAC signature
      hmac_header = request.headers["X-Shopify-Hmac-Sha256"]
      shop_domain = request.headers["X-Shopify-Shop-Domain"]

      unless hmac_header && shop_domain
        head :unauthorized
        nil
      end

      # TODO: Implement proper HMAC verification
      # For now, we'll just check that the headers are present
      # In production, you should verify the HMAC signature against your app's secret
      # Example:
      # data = request.body.read
      # digest = OpenSSL::Digest.new('sha256')
      # calculated_hmac = Base64.strict_encode64(OpenSSL::HMAC.digest(digest, ENV['SHOPIFY_API_SECRET'], data))
      # unless ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
      #   head :unauthorized
      #   return
      # end
    end

    def find_store
      shop_domain = request.headers["X-Shopify-Shop-Domain"]
      @store = Store.find_by(shopify_domain: shop_domain)

      unless @store
        Rails.logger.warn "Order webhook: Store not found for domain: #{shop_domain}"
        head :not_found
      end
    end
  end
end
