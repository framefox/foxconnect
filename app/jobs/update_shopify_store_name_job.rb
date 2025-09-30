class UpdateShopifyStoreNameJob < ApplicationJob
  queue_as :default

  def perform(store)
    return unless store.platform == "shopify"
    return unless store.shopify_token.present?

    Rails.logger.info "Updating Shopify store name for: #{store.shopify_domain}"

    begin
      store.update_name_from_shopify!
    rescue => e
      Rails.logger.error "Failed to update Shopify store name for #{store.shopify_domain}: #{e.message}"
      raise e
    end
  end
end


