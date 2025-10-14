module Webhooks
  class FulfillmentsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_webhook

    def create
      webhook_data = JSON.parse(request.body.read)

      # Find the order by shopify_remote_order_id
      order_id = webhook_data["order_id"]
      order = Order.find_by(shopify_remote_order_id: order_id.to_s)

      unless order
        Rails.logger.warn "Fulfillment webhook: Order not found for shopify_remote_order_id: #{order_id}"
        render json: { error: "Order not found" }, status: :not_found
        return
      end

      # Check if fulfillment already exists
      shopify_fulfillment_id = webhook_data["id"]&.to_s
      existing_fulfillment = order.fulfillments.find_by(shopify_fulfillment_id: shopify_fulfillment_id)

      if existing_fulfillment
        Rails.logger.info "Fulfillment already exists: #{shopify_fulfillment_id}"
        render json: { message: "Fulfillment already processed" }, status: :ok
        return
      end

      # Create the fulfillment
      service = InboundFulfillmentService.new(order: order, fulfillment_data: webhook_data)
      fulfillment = service.create_fulfillment

      if fulfillment
        render json: { message: "Fulfillment created successfully", fulfillment_id: fulfillment.id }, status: :created
      else
        Rails.logger.error "Failed to create fulfillment: #{service.errors.join(', ')}"
        render json: { error: "Failed to create fulfillment", details: service.errors }, status: :unprocessable_entity
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in fulfillment webhook: #{e.message}"
      render json: { error: "Invalid JSON" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Fulfillment webhook error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      render json: { error: "Internal server error" }, status: :internal_server_error
    end

    def update
      webhook_data = JSON.parse(request.body.read)

      # Find the fulfillment by shopify_fulfillment_id
      shopify_fulfillment_id = webhook_data["id"]&.to_s
      fulfillment = Fulfillment.find_by(shopify_fulfillment_id: shopify_fulfillment_id)

      unless fulfillment
        Rails.logger.warn "Fulfillment update webhook: Fulfillment not found for id: #{shopify_fulfillment_id}"
        render json: { error: "Fulfillment not found" }, status: :not_found
        return
      end

      # Update the fulfillment
      service = InboundFulfillmentService.new(order: fulfillment.order, fulfillment_data: webhook_data)
      updated_fulfillment = service.update_fulfillment(fulfillment)

      if updated_fulfillment
        render json: { message: "Fulfillment updated successfully", fulfillment_id: updated_fulfillment.id }, status: :ok
      else
        Rails.logger.error "Failed to update fulfillment: #{service.errors.join(', ')}"
        render json: { error: "Failed to update fulfillment", details: service.errors }, status: :unprocessable_entity
      end
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in fulfillment update webhook: #{e.message}"
      render json: { error: "Invalid JSON" }, status: :bad_request
    rescue StandardError => e
      Rails.logger.error "Fulfillment update webhook error: #{e.message}"
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
