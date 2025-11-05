class SquarespaceProductSyncJob < ApplicationJob
  queue_as :default

  def perform(store)
    return unless store.platform == "squarespace"
    return unless store.squarespace_token.present?

    # Skip sync for inactive stores
    unless store.active?
      Rails.logger.warn "Skipping product sync for inactive store: #{store.name}"
      return
    end

    Rails.logger.info "Starting product sync for store: #{store.name} (#{store.squarespace_domain})"

    begin
      service = SquarespaceProductSyncService.new(store)
      result = service.sync_all_products

      Rails.logger.info "Sync service completed successfully. Result: #{result.inspect}"

      # Update store sync timestamp
      Rails.logger.info "Updating store last_sync_at timestamp..."
      store.update!(last_sync_at: Time.current)

      Rails.logger.info "Product sync completed for store: #{store.name}. Synced #{result[:products_synced]} products, #{result[:variants_synced]} variants, skipped #{result[:products_skipped]} non-physical products"

    rescue => e
      Rails.logger.error "Product sync failed for store: #{store.name}. Error: #{e.message}"
      Rails.logger.error "Error class: #{e.class}"
      Rails.logger.error e.backtrace[0..10].join("\n")
      
      # Check if there are invalid products
      if store.products.any?
        Rails.logger.error "Store has #{store.products.count} products"
        invalid_products = store.products.select { |p| !p.valid? }
        if invalid_products.any?
          Rails.logger.error "Found #{invalid_products.count} invalid products:"
          invalid_products.each do |p|
            Rails.logger.error "  Product #{p.id}: #{p.errors.full_messages.join(', ')}"
          end
        end
      end
      
      raise e
    end
  end
end

