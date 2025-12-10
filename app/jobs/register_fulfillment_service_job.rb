class RegisterFulfillmentServiceJob < ApplicationJob
  queue_as :default

  def perform(store)
    return unless store.platform == "shopify"
    return unless store.shopify_token.present?
    return unless store.active?

    # Skip if already registered
    if store.shopify_fulfillment_service_id.present?
      Rails.logger.info "Fulfillment service already registered for store: #{store.name}"
      return
    end

    Rails.logger.info "Registering fulfillment service for store: #{store.name}"

    begin
      service = FulfillmentServiceRegistrationService.new(store)
      result = service.register!

      if result[:success]
        Rails.logger.info "Successfully registered fulfillment service for #{store.name}"
        Rails.logger.info "  Fulfillment Service ID: #{result[:fulfillment_service_id]}"
        Rails.logger.info "  Location ID: #{result[:location_id]}"
      else
        Rails.logger.error "Failed to register fulfillment service for #{store.name}: #{result[:error]}"
      end
    rescue ShopifyIntegration::InactiveStoreError => e
      Rails.logger.warn "Skipping fulfillment service registration for inactive store: #{e.message}"
    rescue => e
      Rails.logger.error "Exception registering fulfillment service for #{store.name}: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end
  end
end

