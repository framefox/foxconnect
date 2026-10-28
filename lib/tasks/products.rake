namespace :products do
  desc "Sync products for stores that had updates in the last hour"
  task sync_updated: :environment do
    one_hour_ago = 1.hour.ago

    stores_to_sync = Store.shopify_stores.active.where(
      "products_last_updated_at >= :since OR product_sync_state ->> 'status' = 'running'",
      since: one_hour_ago
    )

    if stores_to_sync.any?
      puts "Found #{stores_to_sync.count} store(s) with recent product updates or unfinished syncs"

      stores_to_sync.find_each do |store|
        puts "Syncing products for: #{store.name} (last updated: #{store.products_last_updated_at})"

        begin
          store.sync_shopify_products!
          puts "✓ Queued product sync for: #{store.name}"
        rescue => e
          puts "✗ Error syncing products for #{store.name}: #{e.message}"
          Rails.logger.error "Product sync error for store #{store.id}: #{e.message}"
          Rails.logger.error e.backtrace.join("\n")
        end
      end

      puts "Product sync batch complete"
    else
      puts "No stores need product sync at this time"
    end
  end
end
