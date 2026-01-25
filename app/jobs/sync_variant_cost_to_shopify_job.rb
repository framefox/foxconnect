class SyncVariantCostToShopifyJob < ApplicationJob
  queue_as :default

  def perform(variant_mapping_id)
    variant_mapping = VariantMapping.find_by(id: variant_mapping_id)
    
    # Return early if the mapping no longer exists
    unless variant_mapping
      Rails.logger.info "Variant mapping #{variant_mapping_id} no longer exists, skipping cost sync"
      return
    end

    product_variant = variant_mapping.product_variant
    
    # Validate we have the required data
    unless product_variant&.external_variant_id.present?
      Rails.logger.info "No external variant ID for variant mapping #{variant_mapping_id}, skipping cost sync"
      return
    end

    unless product_variant&.product&.external_id.present?
      Rails.logger.info "No external product ID for variant mapping #{variant_mapping_id}, skipping cost sync"
      return
    end

    store = variant_mapping.store
    
    unless store&.shopify? && store&.active?
      Rails.logger.info "Store not active or not Shopify for variant mapping #{variant_mapping_id}, skipping cost sync"
      return
    end

    # Convert cents to dollars for Shopify API
    cost_dollars = variant_mapping.frame_sku_cost_cents / 100.0

    Rails.logger.info "Syncing cost #{cost_dollars} to Shopify variant #{product_variant.external_variant_id}"

    result = store.sync_variant_cost(
      shopify_variant_id: product_variant.external_variant_id,
      shopify_product_id: product_variant.product.external_id,
      cost: cost_dollars
    )

    if result&.dig(:success)
      Rails.logger.info "Successfully synced cost #{cost_dollars} to Shopify variant #{product_variant.external_variant_id}"
    else
      Rails.logger.error "Failed to sync cost to Shopify variant #{product_variant.external_variant_id}: #{result&.dig(:error)}"
    end
  rescue ShopifyAPI::Errors::HttpResponseError => e
    # Handle Shopify API errors (including auth errors)
    store = VariantMapping.find_by(id: variant_mapping_id)&.store
    if store
      error_handler = StoreConnectionErrorHandler.new(store)
      error_handler.handle_error(e.message)
    end

    Rails.logger.error "Shopify API error in variant cost sync for mapping #{variant_mapping_id}: #{e.message}"
  rescue => e
    Rails.logger.error "Error syncing variant cost for mapping #{variant_mapping_id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
  end
end
