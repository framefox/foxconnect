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

    def destroy
      removed_at = Time.current
      product_id = webhook_payload["id"]&.to_s
      product = @store.products.find_by(external_id: product_id)

      if product
        archive_result = product.archive_from_source!(timestamp: removed_at)
        Rails.logger.info(
          "Archived Shopify product #{product.external_id} from delete webhook " \
          "(product_archived=#{archive_result[:product_archived]}, variants_archived=#{archive_result[:variants_archived]})"
        )
      else
        Rails.logger.info "Received Shopify product delete webhook for unknown product #{product_id} on store #{@store.name}"
      end

      mark_store_for_sync
      log_webhook_received("product deleted")
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
      webhook_data = webhook_payload
      product_id = webhook_data["id"]
      product_title = webhook_data["title"] || "[deleted product]"

      Rails.logger.info "Product webhook (#{action}): #{product_title} (ID: #{product_id}) from store: #{@store.name}"
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in product webhook: #{e.message}"
    end

    def webhook_payload
      request.body.rewind
      payload = JSON.parse(request.body.read)
      request.body.rewind
      payload
    end
  end
end
