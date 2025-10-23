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

    # Fetch and save the product's featured image from Shopify
    update_product_featured_image(product, sync_service)

    { synced: results[:successful], errors: results[:errors] }
  end

  private

  def update_product_featured_image(product, sync_service)
    Rails.logger.info "Fetching featured image from Shopify for product: #{product.title}"

    featured_image_result = sync_service.fetch_product_featured_image(product.external_id)

    if featured_image_result[:success] && featured_image_result[:image_url]
      product.update(featured_image_url: featured_image_result[:image_url])
      Rails.logger.info "✅ Updated featured image for product #{product.title}"
    elsif featured_image_result[:success] && featured_image_result[:image_url].nil?
      Rails.logger.info "No featured image to update for product #{product.title}"
    else
      Rails.logger.warn "⚠️ Failed to fetch featured image for product #{product.title}: #{featured_image_result[:error]}"
    end
  rescue => e
    Rails.logger.error "Error updating product featured image: #{e.message}"
  end
end
