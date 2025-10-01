class SyncProductVariantMappingsJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)

    Rails.logger.info "Starting default variant mapping sync for product: #{product.title} (ID: #{product.id})"

    # Get only the default variant mappings for this product
    # (one variant mapping per product variant, not associated with any order items)
    variant_mappings = product.product_variants.map(&:default_variant_mapping).compact

    if variant_mappings.empty?
      Rails.logger.info "No default variant mappings found for product #{product.title}"
      return { synced: 0, errors: [] }
    end

    # Prepare batch data for the sync service
    variant_image_data = variant_mappings.map do |variant_mapping|
      {
        shopify_variant_id: variant_mapping.product_variant.external_variant_id,
        image_url: variant_mapping.framed_preview_url(size: 1000),
        shopify_product_id: variant_mapping.product_variant.product.external_id,
        alt_text: variant_mapping.frame_sku_title
      }
    end

    # Use the batch sync service
    store = product.store
    sync_service = ShopifyVariantImageSyncService.new(store)
    results = sync_service.batch_sync_variant_images(variant_image_data)

    Rails.logger.info "Completed default variant mapping sync for product #{product.title}: #{results[:successful]} synced, #{results[:failed]} failed"

    { synced: results[:successful], errors: results[:errors] }
  end
end
