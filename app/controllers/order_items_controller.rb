class OrderItemsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [ :create ]
  before_action :set_order_item, only: [ :remove_variant_mapping, :soft_delete, :restore ]

  def create
    # Ensure order is in draft state
    unless @order.draft?
      return render json: {
        success: false,
        error: "Can only add custom items to draft orders"
      }, status: :unprocessable_entity
    end

    # Create custom order item
    @order_item = @order.order_items.build(order_item_params.merge(is_custom: true))

    if @order_item.save
      # Log activity
      OrderActivityService.new(order: @order).log_custom_item_added(
        order_item: @order_item,
        actor: current_user
      )

      render json: {
        success: true,
        message: "Custom order item added successfully",
        order_item: {
          id: @order_item.id,
          display_name: @order_item.display_name,
          quantity: @order_item.quantity
        }
      }, status: :created
    else
      render json: {
        success: false,
        error: @order_item.errors.full_messages.join(", ")
      }, status: :unprocessable_entity
    end
  end

  def remove_variant_mapping
    @order_item.update!(variant_mapping: nil)

    render json: {
      success: true,
      message: "Variant mapping removed from order item"
    }, status: :ok
  rescue => e
    Rails.logger.error "Error removing variant mapping from order item #{@order_item.id}: #{e.message}"
    render json: {
      success: false,
      error: "Failed to remove variant mapping: #{e.message}"
    }, status: :unprocessable_entity
  end

  def soft_delete
    @order_item.soft_delete!

    # Log activity
    OrderActivityService.new(order: @order_item.order).log_item_removed(
      order_item: @order_item,
      actor: current_user
    )

    render json: {
      success: true,
      message: "Order item removed successfully"
    }, status: :ok
  rescue => e
    Rails.logger.error "Error soft deleting order item #{@order_item.id}: #{e.message}"
    render json: {
      success: false,
      error: "Failed to remove order item: #{e.message}"
    }, status: :unprocessable_entity
  end

  def restore
    @order_item.restore!

    # Log activity
    OrderActivityService.new(order: @order_item.order).log_item_restored(
      order_item: @order_item,
      actor: current_user
    )

    render json: {
      success: true,
      message: "Order item restored successfully"
    }, status: :ok
  rescue => e
    Rails.logger.error "Error restoring order item #{@order_item.id}: #{e.message}"
    render json: {
      success: false,
      error: "Failed to restore order item: #{e.message}"
    }, status: :unprocessable_entity
  end

  private

  def set_order
    # Find order by uid that belongs to current user (either manual or imported)
    @order = Order.left_outer_joins(:store)
                  .where("orders.user_id = ? OR stores.user_id = ?", current_user.id, current_user.id)
                  .find_by!(uid: params[:order_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Order not found" }, status: :not_found
  end

  def set_order_item
    # Ensure the order item belongs to an order owned by the user (manual or imported)
    @order_item = OrderItem.joins(:order)
                           .merge(Order.left_outer_joins(:store).where("orders.user_id = ? OR stores.user_id = ?", current_user.id, current_user.id))
                           .find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Order item not found" }, status: :not_found
  end

  def order_item_params
    params.require(:order_item).permit(:variant_title, :quantity)
  end
end
