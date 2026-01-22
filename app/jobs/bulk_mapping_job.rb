class BulkMappingJob < ApplicationJob
  queue_as :default

  def perform(bulk_mapping_request_id:, frame_sku_params:, country_code:)
    bulk_mapping_request = BulkMappingRequest.find(bulk_mapping_request_id)
    store = bulk_mapping_request.store
    variant_title = bulk_mapping_request.variant_title

    Rails.logger.info "Starting bulk mapping job ##{bulk_mapping_request_id} for store: #{store.name}, variant title: #{variant_title}"

    # Mark as processing
    bulk_mapping_request.mark_processing!

    # Find all variants with this title
    product_variants = store.product_variants.where(title: variant_title)

    if product_variants.empty?
      bulk_mapping_request.mark_failed!("No variants found with title: #{variant_title}")
      return
    end

    created_count = 0
    skipped_count = 0
    errors = []
    processed_count = 0

    product_variants.find_each do |variant|
      begin
        # Get or create bundle for this variant
        bundle = variant.bundle || variant.create_bundle!(slot_count: 1)

        # Check if a mapping already exists for this bundle slot and country
        existing_mapping = VariantMapping.find_by(
          bundle_id: bundle.id,
          slot_position: 1,
          country_code: country_code
        )

        if existing_mapping
          skipped_count += 1
        else
          # Create the variant mapping
          VariantMapping.create!(
            product_variant_id: variant.id,
            bundle_id: bundle.id,
            slot_position: 1,
            country_code: country_code,
            frame_sku_id: frame_sku_params["id"].to_i,
            frame_sku_code: frame_sku_params["code"],
            frame_sku_title: frame_sku_params["title"],
            frame_sku_description: frame_sku_params["description"],
            frame_sku_cost_cents: frame_sku_params["cost_cents"].to_i,
            frame_sku_long: frame_sku_params["long"],
            frame_sku_short: frame_sku_params["short"],
            frame_sku_unit: frame_sku_params["unit"],
            colour: frame_sku_params["colour"],
            preview_url: frame_sku_params["preview_image"],
            is_default: true
          )

          created_count += 1
        end
      rescue => e
        error_message = "#{variant.product.title} - #{variant.title}: #{e.message}"
        errors << error_message
        Rails.logger.error "Error creating bulk mapping for variant #{variant.id}: #{e.message}"
      end

      processed_count += 1

      # Update progress every 5 variants (or at the end)
      if processed_count % 5 == 0
        bulk_mapping_request.update!(
          created_count: created_count,
          skipped_count: skipped_count
        )
      end
    end

    # Mark as completed
    bulk_mapping_request.mark_completed!(
      created_count: created_count,
      skipped_count: skipped_count,
      errors: errors
    )

    Rails.logger.info "Completed bulk mapping job ##{bulk_mapping_request_id}: #{created_count} created, #{skipped_count} skipped, #{errors.count} errors"
  rescue => e
    Rails.logger.error "Bulk mapping job ##{bulk_mapping_request_id} failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    # Try to mark as failed if we can find the request
    if defined?(bulk_mapping_request) && bulk_mapping_request
      bulk_mapping_request.mark_failed!(e.message)
    end

    raise
  end
end
