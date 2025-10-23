class Connections::Stores::ProductVariantsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product_variant, only: [ :toggle_fulfilment, :set_fulfilment ]
  skip_before_action :verify_authenticity_token, only: [ :toggle_fulfilment, :set_fulfilment ]

  def toggle_fulfilment
    @product_variant.update!(fulfilment_active: !@product_variant.fulfilment_active)

    # Log activity to orders that have active order items with this variant
    log_fulfilment_toggle_to_orders(@product_variant, @product_variant.fulfilment_active)

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

    # Log activity to orders that have active order items with this variant
    log_fulfilment_toggle_to_orders(@product_variant, target_state)

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
        redirect_to connections_store_product_path(@store, @product_variant.product),
                    notice: @product_variant.fulfilment_active ?
                      "Variant enabled for Framefox fulfilment" :
                      "Variant disabled for Framefox fulfilment",
                    status: :see_other
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
    @store = Store.find_by!(uid: params[:store_uid])
  end

  def set_product_variant
    @product_variant = @store.product_variants.find(params[:id])
  end

  def log_fulfilment_toggle_to_orders(product_variant, enabled)
    # Find all active order items with this product variant in non-completed orders
    order_items = OrderItem.active
                           .joins(:order)
                           .where(product_variant: product_variant)
                           .where.not(orders: { aasm_state: [ :completed, :cancelled ] })
                           .includes(:order)

    # Log activity to each order that has this variant
    order_items.group_by(&:order).each do |order, items|
      items.each do |order_item|
        OrderActivityService.new(order: order).log_item_fulfilment_toggled(
          order_item: order_item,
          enabled: enabled,
          actor: current_user
        )
      end
    end
  end
end
