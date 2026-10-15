namespace :shopify do
  desc "Migrate active merchant stores to expiring offline tokens (run after deploying token storage)"
  task migrate_tokens: :environment do
    Store.shopify_stores.active.where(refresh_token: nil).find_each do |store|
      next if store.shopify_token.blank?
      store.with_lock do
        next if store.refresh_token.present?
        session = ShopifyAPI::Auth::TokenExchange.migrate_to_expiring_token(
          shop: store.shopify_domain, non_expiring_offline_token: store.shopify_token
        )
        store.update!(shopify_token: session.access_token, access_scopes: session.scope.to_s,
          expires_at: session.expires, refresh_token: session.refresh_token,
          refresh_token_expires_at: session.refresh_token_expires)
      end
      puts "Migrated store #{store.id}"
    end
  end
end
