class Connections::Stores::ProductsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product, only: [ :show, :sync_from_platform, :toggle_fulfilment, :sync_variant_mappings, :toggle_bundles ]
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

  private

  def set_store
    @store = Store.find_by!(uid: params[:store_uid])
  end

  def set_product
    @product = @store.products.find(params[:id])
  end
end
