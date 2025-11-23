class SyncProductVariantMappingsJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)
    store = product.store

    Rails.logger.info "Starting default variant mapping sync for product: #{product.title} (ID: #{product.id}) on #{store.platform}"

    # Get only the default variant mappings for this product
    # (one variant mapping per product variant, not associated with any order items)
    variant_mappings = product.product_variants.map(&:default_variant_mapping).compact

    if variant_mappings.empty?
      Rails.logger.info "No default variant mappings found for product #{product.title}"
      return { synced: 0, errors: [] }
    end

    # Prepare batch data for the sync service (platform-agnostic field names)
    variant_image_data = variant_mappings.map do |variant_mapping|
      {
        variant_id: variant_mapping.product_variant.external_variant_id,
        image_url: variant_mapping.framed_preview_url(size: 1000),
        product_id: variant_mapping.product_variant.product.external_id,
        alt_text: variant_mapping.frame_sku_title
      }
    end

    # Use the appropriate sync service based on platform
    results = case store.platform
    when "shopify"
      # Shopify service expects shopify_variant_id and shopify_product_id
      shopify_data = variant_image_data.map do |data|
        {
          shopify_variant_id: data[:variant_id],
          shopify_product_id: data[:product_id],
          image_url: data[:image_url],
          alt_text: data[:alt_text]
        }
      end
      sync_service = ShopifyVariantImageSyncService.new(store)
      sync_service.batch_sync_variant_images(shopify_data)
    when "squarespace"
      # Squarespace service expects squarespace_variant_id and squarespace_product_id
      squarespace_data = variant_image_data.map do |data|
        {
          squarespace_variant_id: data[:variant_id],
          squarespace_product_id: data[:product_id],
          image_url: data[:image_url],
          alt_text: data[:alt_text]
        }
      end
      sync_service = SquarespaceVariantImageSyncService.new(store)
      sync_service.batch_sync_variant_images(squarespace_data)
    when "wix"
      # Wix not yet implemented
      Rails.logger.warn "Image sync not yet implemented for Wix stores"
      { successful: 0, failed: variant_mappings.count, errors: [ "Image sync not yet available for Wix stores" ] }
    else
      Rails.logger.error "Unsupported platform: #{store.platform}"
      { successful: 0, failed: variant_mappings.count, errors: [ "Unsupported platform: #{store.platform}" ] }
    end

    Rails.logger.info "Completed default variant mapping sync for product #{product.title}: #{results[:successful]} synced, #{results[:failed]} failed"

    # Fetch and save the product's featured image (only for Shopify for now)
    if store.shopify? && results[:successful] > 0
      update_product_featured_image(product, ShopifyVariantImageSyncService.new(store))
    end

    { synced: results[:successful], errors: results[:errors] }
  rescue ShopifyAPI::Errors::HttpResponseError => e
    # Handle Shopify API errors (including auth errors)
    error_handler = StoreConnectionErrorHandler.new(store)
    error_handler.handle_error(e.message)

    Rails.logger.error "Shopify API error in variant mapping sync for product #{product.id}: #{e.message}"
    { synced: 0, errors: [ e.message ] }
  rescue => e
    # Log other errors but don't flag for reauthentication
    Rails.logger.error "Error in variant mapping sync for product #{product.id}: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    raise
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
