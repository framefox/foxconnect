module Webhooks
  class AppController < ApplicationController
    include ShopifyWebhookVerification

    def uninstalled
      webhook_data = JSON.parse(request.body.read)
      shop_domain = webhook_data["domain"] || request.headers["X-Shopify-Shop-Domain"]

      # Find the store - but don't fail if it doesn't exist
      # (it might have already been deleted or marked inactive)
      store = Store.find_by(shopify_domain: shop_domain)

      if store
        Rails.logger.info "App uninstalled: #{store.name} (#{shop_domain})"

        # Mark store as inactive, flag for reauthentication, and clear fulfillment data
        # Note: Keep shopify_token as-is (ShopifyApp validation requires it to be present)
        # The token is already invalid since the app was uninstalled, and will be replaced on reconnect
        store.update(
          active: false,
          needs_reauthentication: true,
          reauthentication_flagged_at: Time.current,
          shopify_fulfillment_service_id: nil,  # Clear orphaned fulfillment service
          shopify_fulfillment_location_id: nil  # Clear orphaned location
        )

        # Send notification email to store owner
        StoreMailer.with(store: store).reauthentication_required.deliver_later if store.user&.email.present?

        # Log the uninstall activity
        Rails.logger.info "Marked store #{store.name} as inactive, cleared access token, and flagged for reauthentication"

        # Optional: Send notification to admin
        # AdminMailer.app_uninstalled(store).deliver_later
      else
        # Store not found - probably already deleted or this is a duplicate webhook
        # Return 200 OK anyway to prevent Shopify from retrying
        Rails.logger.warn "App uninstall webhook: Store not found for domain: #{shop_domain} (already deleted or duplicate webhook)"
      end

      head :ok
    rescue JSON::ParserError => e
      Rails.logger.error "Invalid JSON in app uninstall webhook: #{e.message}"
      head :bad_request
    rescue StandardError => e
      Rails.logger.error "App uninstall webhook error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      head :internal_server_error
    end
  end
end
