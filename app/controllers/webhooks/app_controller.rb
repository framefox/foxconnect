module Webhooks
  class AppController < ApplicationController
    include ShopifyWebhookVerification

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

    def find_store
      @store = find_store_by_webhook_headers
    end
  end
end
