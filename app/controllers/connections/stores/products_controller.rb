class Connections::Stores::ProductsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product, only: [ :show, :sync_from_platform, :toggle_fulfilment, :sync_variant_mappings, :toggle_bundles, :update_bundle_slot_count ]
  skip_before_action :verify_authenticity_token, only: [ :toggle_fulfilment ]

  def show
    @variants = @product.product_variants.includes(:variant_mappings, :bundle).order(:position)
    @variant_count = @variants.count
  end

  def sync_from_platform
    # Future: Sync individual product from platform
    redirect_to connections_store_path(@store),
                notice: "Product sync from #{@store.platform.humanize} initiated for #{@product.title}."
  end

  def toggle_fulfilment
    new_state = !@product.fulfilment_active

    # Update product
    @product.update!(fulfilment_active: new_state)

    # Update all child variants to match product state
    @product.product_variants.update_all(fulfilment_active: new_state)

    render json: {
      success: true,
      fulfilment_active: @product.fulfilment_active,
      variants_updated: @product.product_variants.count,
      message: @product.fulfilment_active ?
        "Product and all variants enabled for Framefox fulfilment" :
        "Product and all variants disabled for Framefox fulfilment"
    }
  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  def sync_variant_mappings
    # Count only the default variant mappings for variants with fulfilment enabled
    # (one variant mapping per product variant, not associated with any order items)
    variant_mappings_count = @product.product_variants.where(fulfilment_active: true).map(&:default_variant_mapping).compact.count

    if variant_mappings_count == 0
      flash[:alert] = "No variant mappings found for #{@product.title} with fulfilment enabled. Enable fulfilment on variants and create variant mappings first."
      redirect_to connections_store_product_path(@store, @product) and return
    end

    # Queue the job
    SyncProductVariantMappingsJob.perform_later(@product.id)

    flash[:notice] = "Sync initiated for #{@product.title}. #{variant_mappings_count} variant image(s) with fulfilment enabled will be synced to #{@store.platform.humanize}."
    redirect_to connections_store_product_path(@store, @product)
  rescue => e
    Rails.logger.error "Error initiating variant image sync: #{e.message}"
    flash[:alert] = "Failed to initiate sync: #{e.message}"
    redirect_to connections_store_product_path(@store, @product)
  end

  def toggle_bundles
    @product.update!(bundles_enabled: !@product.bundles_enabled)
    
    flash[:notice] = @product.bundles_enabled ? 
      "Bundles enabled for #{@product.title}" : 
      "Bundles disabled for #{@product.title}"
    redirect_to connections_store_product_path(@store, @product)
  rescue => e
    flash[:alert] = "Failed to toggle bundles: #{e.message}"
    redirect_to connections_store_product_path(@store, @product)
  end

  def update_bundle_slot_count
    new_slot_count = params[:slot_count].to_i

    # Validate slot count
    unless new_slot_count.between?(1, 10)
      render json: { success: false, error: "Slot count must be between 1-10" }, status: :unprocessable_entity
      return
    end

    updated_count = 0

    @product.product_variants.each do |pv|
      bundle = pv.bundle || pv.create_bundle!(slot_count: 1)

      # Check if reducing slots - remove extra mappings
      if new_slot_count < bundle.slot_count
        bundle.variant_mappings.where("slot_position > ?", new_slot_count).destroy_all
      end

      # Check if increasing slots - copy first slot mapping to new slots
      if new_slot_count > bundle.slot_count
        first_slot_mapping = bundle.variant_mappings.find_by(slot_position: 1)

        if first_slot_mapping.present?
          # Create copies for each new slot position (without image - user must add images separately)
          ((bundle.slot_count + 1)..new_slot_count).each do |new_position|
            # Create the new mapping as a copy of the first slot (without image)
            VariantMapping.create!(
              bundle_id: bundle.id,
              product_variant_id: pv.id,
              slot_position: new_position,
              country_code: first_slot_mapping.country_code,
              image: nil,
              frame_sku_id: first_slot_mapping.frame_sku_id,
              frame_sku_code: first_slot_mapping.frame_sku_code,
              frame_sku_title: first_slot_mapping.frame_sku_title,
              frame_sku_description: first_slot_mapping.frame_sku_description,
              frame_sku_cost_cents: first_slot_mapping.frame_sku_cost_cents,
              frame_sku_long: first_slot_mapping.frame_sku_long,
              frame_sku_short: first_slot_mapping.frame_sku_short,
              frame_sku_unit: first_slot_mapping.frame_sku_unit,
              width: first_slot_mapping.width,
              height: first_slot_mapping.height,
              unit: first_slot_mapping.unit,
              colour: first_slot_mapping.colour,
              preview_url: first_slot_mapping.preview_url,
              is_default: false
            )
          end
        end
      end

      bundle.update!(slot_count: new_slot_count)
      updated_count += 1
    end

    render json: {
      success: true,
      slot_count: new_slot_count,
      variants_updated: updated_count
    }
  rescue => e
    Rails.logger.error "Error updating bundle slot count: #{e.message}"
    render json: {
      success: false,
      error: "Failed to update bundle size: #{e.message}"
    }, status: :unprocessable_entity
  end

  private

  def set_store
    @store = Store.find_by!(uid: params[:store_uid])
  end

  def set_product
    @product = @store.products.find(params[:id])
  end
end
