class Connections::Stores::ProductsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product, only: [ :show, :sync_from_platform, :toggle_fulfilment, :sync_variant_mappings ]
  skip_before_action :verify_authenticity_token, only: [ :toggle_fulfilment ]

  def show
    @variants = @product.product_variants.includes(:variant_mapping).order(:position)
    @variant_count = @variants.count
  end

  def sync_from_platform
    # Future: Sync individual product from platform
    redirect_to connections_store_path(@store),
                notice: "Product sync from #{@store.platform.humanize} initiated for #{@product.title}."
  end

  def toggle_fulfilment
    @product.update!(fulfilment_active: !@product.fulfilment_active)

    render json: {
      success: true,
      fulfilment_active: @product.fulfilment_active,
      message: @product.fulfilment_active ?
        "Product enabled for Framefox fulfilment" :
        "Product disabled for Framefox fulfilment"
    }
  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  def sync_variant_mappings
    # Count variant mappings for this product
    variant_mappings_count = VariantMapping.joins(:product_variant)
                                          .where(product_variants: { product_id: @product.id })
                                          .count

    if variant_mappings_count == 0
      flash[:alert] = "No variant mappings found for #{@product.title}. Create some variant mappings first."
      redirect_to connections_store_product_path(@store, @product) and return
    end

    # Queue the job
    SyncProductVariantMappingsJob.perform_later(@product.id)

    flash[:notice] = "Variant mapping sync initiated for #{@product.title}. #{variant_mappings_count} variant(s) will be synced to Shopify."
    redirect_to connections_store_product_path(@store, @product)
  rescue => e
    Rails.logger.error "Error initiating variant mapping sync: #{e.message}"
    flash[:alert] = "Failed to initiate sync: #{e.message}"
    redirect_to connections_store_product_path(@store, @product)
  end

  private

  def set_store
    @store = Store.find(params[:store_id])
  end

  def set_product
    @product = @store.products.find(params[:id])
  end
end
