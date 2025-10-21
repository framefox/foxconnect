module Webhooks
  class ProductsController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_webhook
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
        Rails.logger.warn "Product webhook: Store not found for domain: #{shop_domain}"
        head :not_found
      end
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
