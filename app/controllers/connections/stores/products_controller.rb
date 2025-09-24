class Connections::Stores::ProductsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product, only: [ :show, :sync_from_platform, :toggle_fulfilment ]
  skip_before_action :verify_authenticity_token, only: [ :toggle_fulfilment ]

  def index
    @products = @store.products.includes(:product_variants)
                     .order(created_at: :desc)

    @products_count = @store.products.count
    @variants_count = @store.product_variants.count
    @last_sync = @store.last_sync_at
  end

  def show
    @variants = @product.product_variants.order(:position)
    @variant_count = @variants.count
  end

  def sync_from_platform
    # Future: Sync individual product from platform
    redirect_to connections_store_products_path(@store),
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

  private

  def set_store
    @store = Store.find(params[:store_id])
  end

  def set_product
    @product = @store.products.find(params[:id])
  end
end
