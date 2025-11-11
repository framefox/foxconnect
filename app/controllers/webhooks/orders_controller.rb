module Webhooks
  # Handles webhooks from MERCHANT STORES that install the app
  # Requires HMAC verification for security
  class OrdersController < ApplicationController
    include ShopifyWebhookVerification

    before_action :find_store

    def create
      webhook_data = JSON.parse(request.body.read)
      order_id = webhook_data["id"]

      Rails.logger.info "Order create webhook received for order: #{order_id} from store: #{@store.name}"

      # Check if order import is paused for this store
      if @store.order_import_paused?
        Rails.logger.info "Order import is paused for store: #{@store.name}. Skipping order #{order_id}"
        render json: { message: "Order import paused for this store", skipped: true }, status: :ok
        return
      end

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

    private

    def find_store
      @store = find_store_by_webhook_headers
    end
  end
end
