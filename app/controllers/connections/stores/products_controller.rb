class Connections::Stores::ProductsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product, only: [ :show, :sync_from_platform, :toggle_fulfilment, :sync_variant_mappings ]
  skip_before_action :verify_authenticity_token, only: [ :toggle_fulfilment ]

  def show
    @variants = @product.product_variants.includes(:variant_mappings).order(:position)
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
    # Count only the default variant mappings for this product
    # (one variant mapping per product variant, not associated with any order items)
    variant_mappings_count = @product.product_variants.map(&:default_variant_mapping).compact.count

    if variant_mappings_count == 0
      flash[:alert] = "No default variant mappings found for #{@product.title}. Create some variant mappings first."
      redirect_to connections_store_product_path(@store, @product) and return
    end

    # Queue the job
    SyncProductVariantMappingsJob.perform_later(@product.id)

    flash[:notice] = "Sync initiated for #{@product.title}. #{variant_mappings_count} default variant image(s) will be synced to Shopify."
    redirect_to connections_store_product_path(@store, @product)
  rescue => e
    Rails.logger.error "Error initiating variant image sync: #{e.message}"
    flash[:alert] = "Failed to initiate sync: #{e.message}"
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
