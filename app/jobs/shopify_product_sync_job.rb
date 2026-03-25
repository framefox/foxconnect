class ShopifyProductSyncJob < ApplicationJob
  queue_as :default

  def perform(store)
    return unless store.platform == "shopify"
    return unless store.shopify_token.present?

    # Skip sync for inactive stores
    unless store.active?
      Rails.logger.warn "Skipping product sync for inactive store: #{store.name}"
      return
    end

    Rails.logger.info "Starting product sync for store: #{store.name} (#{store.shopify_domain})"

    begin
      service = ShopifyProductSyncService.new(store)
      result = service.sync_all_products

      # Update store sync timestamp
      store.update!(last_sync_at: Time.current)

      Rails.logger.info(
        "Product sync completed for store: #{store.name}. " \
        "Updated #{result[:products_updated]} products/#{result[:variants_updated]} variants, " \
        "archived #{result[:products_archived]} products/#{result[:variants_archived]} variants, " \
        "reactivated #{result[:products_reactivated]} products/#{result[:variants_reactivated]} variants, " \
        "failures #{result[:failures].count}"
      )

    rescue ShopifyIntegration::InactiveStoreError => e
      Rails.logger.warn "Product sync skipped for inactive store: #{store.name}"
    rescue => e
      Rails.logger.error "Product sync failed for store: #{store.name}. Error: #{e.message}"
      raise e
    end
  end
end
