class ShopifyProductSyncJob < ApplicationJob
  queue_as :default

  def perform(store)
    return unless store.platform == "shopify"
    return unless store.shopify_token.present?

    Rails.logger.info "Starting product sync for store: #{store.name} (#{store.shopify_domain})"

    begin
      service = ShopifyProductSyncService.new(store)
      result = service.sync_all_products

      # Update store sync timestamp
      store.update!(last_sync_at: Time.current)

      Rails.logger.info "Product sync completed for store: #{store.name}. Synced #{result[:products_synced]} products, #{result[:variants_synced]} variants"

    rescue => e
      Rails.logger.error "Product sync failed for store: #{store.name}. Error: #{e.message}"
      raise e
    end
  end
end
