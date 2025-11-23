namespace :stores do
  desc "Check API connections for all active stores and flag those needing reauthentication"
  task check_api_connections: :environment do
    puts "=" * 80
    puts "Starting API connection check for all active stores"
    puts "=" * 80
    puts ""

    results = {
      total: 0,
      successful: 0,
      failed: 0,
      flagged: 0,
      cleared: 0
    }

    # Check Shopify stores
    shopify_stores = Store.shopify_stores.active
    puts "Checking #{shopify_stores.count} active Shopify store(s)..."
    puts ""

    shopify_stores.each do |store|
      results[:total] += 1
      
      puts "Testing: #{store.name} (#{store.shopify_domain})"
      
      service = StoreApiConnectionTestService.new(store)
      result = service.test_connection

      if result[:success]
        results[:successful] += 1
        puts "  ✅ Connection successful"
        
        # Track if flag was cleared
        if store.reload.needs_reauthentication == false && store.reauthentication_flagged_at_previously_was.present?
          results[:cleared] += 1
          puts "  ℹ️  Reauthentication flag cleared"
        end
      else
        results[:failed] += 1
        puts "  ❌ Connection failed: #{result[:message]}"
        
        # Track if store was newly flagged
        if store.reload.needs_reauthentication?
          results[:flagged] += 1
          puts "  ⚠️  Store flagged for reauthentication"
        end
      end
      
      puts ""
    end

    # Check Squarespace stores (when implemented)
    squarespace_stores = Store.squarespace_stores.active
    if squarespace_stores.any?
      puts "Note: Skipping #{squarespace_stores.count} Squarespace store(s) - connection test not yet implemented"
      puts ""
    end

    # Check Wix stores (when implemented)
    wix_stores = Store.wix_stores.active
    if wix_stores.any?
      puts "Note: Skipping #{wix_stores.count} Wix store(s) - connection test not yet implemented"
      puts ""
    end

    puts "=" * 80
    puts "Connection Check Summary"
    puts "=" * 80
    puts "Total stores checked:     #{results[:total]}"
    puts "Successful connections:   #{results[:successful]}"
    puts "Failed connections:       #{results[:failed]}"
    puts "Newly flagged:            #{results[:flagged]}"
    puts "Flags cleared:            #{results[:cleared]}"
    puts "=" * 80
    puts ""
    puts "Stores currently needing reauthentication: #{Store.where(needs_reauthentication: true).count}"
    puts ""
    puts "Task completed at: #{Time.current.strftime('%Y-%m-%d %H:%M:%S %Z')}"
  end

  desc "Clear reauthentication flag for a specific store"
  task :clear_reauth_flag, [:store_uid] => :environment do |t, args|
    if args[:store_uid].blank?
      puts "Error: Please provide a store UID"
      puts "Usage: rake stores:clear_reauth_flag[STORE_UID]"
      exit 1
    end

    store = Store.find_by(uid: args[:store_uid])
    
    if store.nil?
      puts "Error: Store not found with UID: #{args[:store_uid]}"
      exit 1
    end

    if store.needs_reauthentication?
      error_handler = StoreConnectionErrorHandler.new(store)
      error_handler.clear_reauthentication_flag
      puts "✅ Reauthentication flag cleared for store: #{store.name}"
    else
      puts "ℹ️  Store #{store.name} was not flagged for reauthentication"
    end
  end

  desc "List all stores that need reauthentication"
  task list_reauth_needed: :environment do
    stores = Store.where(needs_reauthentication: true).order(reauthentication_flagged_at: :desc)
    
    if stores.empty?
      puts "✅ No stores currently need reauthentication"
    else
      puts "Stores needing reauthentication (#{stores.count}):"
      puts "=" * 80
      
      stores.each do |store|
        puts "Store: #{store.name}"
        puts "  Platform:    #{store.platform}"
        puts "  Domain:      #{store.shopify_domain}" if store.shopify?
        puts "  Owner:       #{store.user&.email || 'No owner'}"
        puts "  Flagged at:  #{store.reauthentication_flagged_at&.strftime('%Y-%m-%d %H:%M:%S %Z')}"
        puts "  Store UID:   #{store.uid}"
        puts ""
      end
    end
  end
end

