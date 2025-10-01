class Connections::Stores::ProductVariantsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product_variant, only: [ :toggle_fulfilment, :set_fulfilment ]
  skip_before_action :verify_authenticity_token, only: [ :toggle_fulfilment, :set_fulfilment ]

  def toggle_fulfilment
    @product_variant.update!(fulfilment_active: !@product_variant.fulfilment_active)

    render json: {
      success: true,
      fulfilment_active: @product_variant.fulfilment_active,
      message: @product_variant.fulfilment_active ?
        "Variant enabled for Framefox fulfilment" :
        "Variant disabled for Framefox fulfilment"
    }
  rescue => e
    render json: {
      success: false,
      error: e.message
    }, status: :unprocessable_entity
  end

  def set_fulfilment
    target_state = params[:active] == "true"
    @product_variant.update!(fulfilment_active: target_state)

    respond_to do |format|
      format.json do
        render json: {
          success: true,
          fulfilment_active: @product_variant.fulfilment_active,
          message: @product_variant.fulfilment_active ?
            "Variant enabled for Framefox fulfilment" :
            "Variant disabled for Framefox fulfilment"
        }
      end
      format.html do
        redirect_back fallback_location: connections_store_path(@store),
                      notice: @product_variant.fulfilment_active ?
                        "Variant enabled for Framefox fulfilment" :
                        "Variant disabled for Framefox fulfilment"
      end
    end
  rescue => e
    respond_to do |format|
      format.json do
        render json: {
          success: false,
          error: e.message
        }, status: :unprocessable_entity
      end
      format.html do
        redirect_back fallback_location: connections_store_path(@store),
                      alert: "Failed to update fulfilment status: #{e.message}"
      end
    end
  end

  private

  def set_store
    @store = Store.find(params[:store_id])
  end

  def set_product_variant
    @product_variant = @store.product_variants.find(params[:id])
  end
end
