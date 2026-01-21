module Webhooks
  class ProductsController < ApplicationController
    include ShopifyWebhookVerification
    include WebhookLogging

    before_action :find_store

    def create
      mark_store_for_sync
      log_webhook_received("product created")
      head :ok
    end

    def update
      mark_store_for_sync
      log_webhook_received("product updated")
      head :ok
    end

    private

    def find_store
      @store = find_store_by_webhook_headers
    end

    def mark_store_for_sync
      @store.update_column(:products_last_updated_at, Time.current)
      Rails.logger.info "Marked store #{@store.name} for product sync (last updated: #{@store.products_last_updated_at})"
    end

    def log_webhook_received(action)
      webhook_data = JSON.parse(request.body.read)
      product_id = webhook_data["id"]
      product_title = webhook_data["title"]

      Rails.logger.info "Product webhook (#{action}): #{product_title} (ID: #{product_id}) from store: #{@store.name}"
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in product webhook: #{e.message}"
    end
  end
end
