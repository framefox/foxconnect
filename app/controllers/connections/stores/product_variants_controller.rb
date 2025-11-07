class Connections::Stores::ProductVariantsController < Connections::ApplicationController
  before_action :set_store
  before_action :set_product_variant, only: [ :toggle_fulfilment, :set_fulfilment, :update_bundle ]
  skip_before_action :verify_authenticity_token, only: [ :toggle_fulfilment, :set_fulfilment, :update_bundle ]

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
        # Redirect back to the referring page (usually order page or product page)
        redirect_back fallback_location: connections_store_product_path(@store, @product_variant.product),
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

  def update_bundle
    new_slot_count = params[:slot_count].to_i

    # Validate slot count
    unless new_slot_count.between?(1, 10)
      render json: { success: false, error: "Slot count must be between 1-10" }, status: :unprocessable_entity
      return
    end

    bundle = @product_variant.bundle || @product_variant.create_bundle!(slot_count: 1)

    # Check if reducing slots
    if new_slot_count < bundle.slot_count
      # Check if any order items are using the slots that would be removed
      mappings_to_remove = bundle.variant_mappings.where("slot_position > ?", new_slot_count)
      
      if mappings_to_remove.any?
        # Check if these mappings are referenced in any orders
        in_use = VariantMapping.where(
          bundle_id: bundle.id
        ).where("slot_position > ?", new_slot_count).exists?
        
        if in_use
          render json: {
            success: false,
            error: "Cannot reduce slots - existing orders or configuration use these slots"
          }, status: :unprocessable_entity
          return
        end
        
        # Safe to remove
        mappings_to_remove.destroy_all
      end
    end

    # Update slot count
    bundle.update!(slot_count: new_slot_count)

    render json: {
      success: true,
      bundle: {
        id: bundle.id,
        slot_count: bundle.slot_count,
        variant_mappings: bundle.variant_mappings.order(:slot_position).map { |vm|
          {
            id: vm.id,
            slot_position: vm.slot_position,
            frame_sku_title: vm.frame_sku_title,
            frame_sku_cost_formatted: vm.frame_sku_cost_formatted,
            dimensions_display: vm.dimensions_display,
            framed_preview_thumbnail: vm.framed_preview_thumbnail,
            image_filename: vm.image_filename
          }
        }
      }
    }
  rescue => e
    render json: { success: false, error: e.message }, status: :unprocessable_entity
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
