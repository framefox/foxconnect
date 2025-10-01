class SyncProductVariantMappingsJob < ApplicationJob
  queue_as :default

  def perform(product_id)
    product = Product.find(product_id)

    Rails.logger.info "Starting default variant mapping sync for product: #{product.title} (ID: #{product.id})"

    # Get only the default variant mappings for this product
    # (variant mappings that are not associated with any order items)
    variant_mappings = VariantMapping.joins(:product_variant)
                                    .where(product_variants: { product_id: product.id })
                                    .where.not(id: OrderItem.select(:variant_mapping_id).where.not(variant_mapping_id: nil))

    if variant_mappings.empty?
      Rails.logger.info "No default variant mappings found for product #{product.title}"
      return { synced: 0, errors: [] }
    end

    synced_count = 0
    errors = []

    variant_mappings.each do |variant_mapping|
      begin
        result = variant_mapping.sync_to_shopify_variant(size: 1000)

        if result[:success]
          synced_count += 1
          Rails.logger.info "✓ Synced default variant mapping #{variant_mapping.id} (#{variant_mapping.display_name})"
        else
          error_msg = "Failed to sync default variant mapping #{variant_mapping.id}: #{result[:error]}"
          errors << error_msg
          Rails.logger.error error_msg
        end
      rescue StandardError => e
        error_msg = "Exception syncing default variant mapping #{variant_mapping.id}: #{e.message}"
        errors << error_msg
        Rails.logger.error error_msg
      end
    end

    Rails.logger.info "Completed default variant mapping sync for product #{product.title}: #{synced_count} synced, #{errors.count} errors"

    { synced: synced_count, errors: errors }
  end
end
