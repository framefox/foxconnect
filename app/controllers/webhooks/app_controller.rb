module Webhooks
  class AppController < ApplicationController
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_webhook
    before_action :find_store

    def uninstalled
      webhook_data = JSON.parse(request.body.read)
      shop_domain = webhook_data["domain"] || request.headers["X-Shopify-Shop-Domain"]

      Rails.logger.info "App uninstalled: #{@store.name} (#{shop_domain})"

      # Mark store as inactive and clear sensitive data
      @store.update(
        active: false,
        shopify_token: nil  # Invalidate the access token
      )

      # Log the uninstall activity
      Rails.logger.info "Marked store #{@store.name} as inactive and cleared access token"

      # Optional: Send notification to admin
      # AppMailer.app_uninstalled(@store).deliver_later

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in app uninstall webhook: #{e.message}"
      head :bad_request
    rescue StandardError => e
      Rails.logger.error "App uninstall webhook error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
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
    end

    def find_store
      shop_domain = request.headers["X-Shopify-Shop-Domain"]
      @store = Store.find_by(shopify_domain: shop_domain)

      unless @store
        Rails.logger.warn "App uninstall webhook: Store not found for domain: #{shop_domain}"
        head :not_found
      end
    end
  end
end
