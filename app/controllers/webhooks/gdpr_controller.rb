module Webhooks
  class GdprController < ApplicationController
    include ShopifyWebhookVerification
    include WebhookLogging

    # Customers can request their data from a shop owner
    # This webhook is required for App Store compliance
    def customers_data_request
      webhook_data = JSON.parse(request.body.read)
      shop_domain = webhook_data["shop_domain"]
      customer_id = webhook_data.dig("customer", "id")

      Rails.logger.info "GDPR: Customer data request from #{shop_domain} for customer #{customer_id}"

      # Find the store - but don't fail if it doesn't exist
      store = Store.find_by(shopify_domain: shop_domain)

      if store
        # Send email notification to admin
        GdprMailer.customer_data_request(webhook_data).deliver_later

        # TODO: Implement logic to collect and send customer data
        # You should:
        # 1. Collect any customer-related data you have
        # 2. Send it to the shop owner or customer
        Rails.logger.info "GDPR: Processing customer data request for store: #{store.name}"
      else
        # Store not found - log but still return 200 OK
        Rails.logger.warn "GDPR: Customer data request for non-existent store: #{shop_domain} (already deleted or duplicate webhook)"
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in GDPR data request webhook: #{e.message}"
      head :bad_request
    rescue StandardError => e
      Rails.logger.error "GDPR data request error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
    end

    # Customers can request their data be deleted
    # This webhook is required for App Store compliance
    def customers_redact
      webhook_data = JSON.parse(request.body.read)
      shop_domain = webhook_data["shop_domain"]
      customer_id = webhook_data.dig("customer", "id")

      Rails.logger.info "GDPR: Customer redaction request from #{shop_domain} for customer #{customer_id}"

      # Find the store - but don't fail if it doesn't exist
      store = Store.find_by(shopify_domain: shop_domain)

      if store
        # Send email notification to admin
        GdprMailer.customer_redact(webhook_data).deliver_later

        # TODO: Implement logic to delete customer data
        # You should:
        # 1. Find orders/data for this customer
        # 2. Delete/anonymize any customer PII you have stored
        # 3. Confirm deletion in your logs
        Rails.logger.info "GDPR: Processing customer redaction for store: #{store.name}"
      else
        # Store not found - log but still return 200 OK
        Rails.logger.warn "GDPR: Customer redaction request for non-existent store: #{shop_domain} (already deleted or duplicate webhook)"
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in GDPR redact webhook: #{e.message}"
      head :bad_request
    rescue StandardError => e
      Rails.logger.error "GDPR customer redact error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
    end

    # Shop owner deletes their shop
    # This webhook is required for App Store compliance
    def shop_redact
      webhook_data = JSON.parse(request.body.read)
      shop_domain = webhook_data["shop_domain"]
      shop_id = webhook_data["shop_id"]

      Rails.logger.info "GDPR: Shop redaction request from #{shop_domain} (ID: #{shop_id})"

      # Find the store by shopify_domain
      store = Store.find_by(shopify_domain: shop_domain)

      if store
        # Send email notification to admin
        GdprMailer.shop_redact(webhook_data).deliver_later

        # Delete all associated data and the store record
        # Note: This will cascade delete associated records (orders, products, etc.) via dependent: :destroy
        store.destroy
        Rails.logger.info "GDPR: Deleted store and all associated data for: #{shop_domain}"
      else
        # Store not found - already deleted or duplicate webhook
        # Still return 200 OK to acknowledge receipt
        Rails.logger.warn "GDPR: Shop redaction request for non-existent store: #{shop_domain} (already deleted or duplicate webhook)"
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in GDPR shop redact webhook: #{e.message}"
      head :bad_request
    rescue StandardError => e
      Rails.logger.error "GDPR shop redact error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
    end

  end
end
