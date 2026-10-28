module Shopify
  # A bulk catalogue edit sends one webhook per product. The hourly sync only
  # needs to know that the store changed, so the first webhook in a short
  # window stamps the store and the rest return without touching the database.
  class CatalogSyncStamp
    INTERVAL = 30.seconds
    KEY_PREFIX = "shopify:catalog_sync_stamp"

    def self.mark!(store)
      return unless claim(store.id)

      Store.where(id: store.id).update_all(
        products_last_updated_at: Time.current,
        updated_at: Time.current
      )
      Rails.logger.info "Scheduled catalog sync for #{store.name}"
    end

    def self.claim(store_id)
      claimed = Sidekiq.redis do |redis|
        redis.set("#{KEY_PREFIX}:#{store_id}", "1", nx: true, ex: INTERVAL.to_i)
      end
      claimed == true || claimed == "OK"
    rescue StandardError => error
      Rails.logger.warn "Catalog sync stamp fell back to the database: #{error.class}"
      true
    end
  end
end
