class Admin::OrderItemsController < Admin::ApplicationController
  before_action :set_order_item, only: [ :remove_variant_mapping, :soft_delete, :restore, :duplicate, :rename ]

  def remove_variant_mapping
    @order_item.clear_variant_mappings!

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

  def duplicate
    return unless ensure_custom_item!
    return unless ensure_draft_order!

    duplicated_item = @order_item.duplicate_custom_item!

    OrderActivityService.new(order: @order_item.order).log_custom_item_duplicated(
      source_order_item: @order_item,
      duplicated_order_item: duplicated_item,
      actor: current_user
    )

    render json: {
      success: true,
      message: "Custom order item duplicated successfully",
      order_item: {
        id: duplicated_item.id,
        display_name: duplicated_item.display_name,
        quantity: duplicated_item.quantity
      }
    }, status: :created
  rescue => e
    Rails.logger.error "Error duplicating order item #{@order_item.id}: #{e.message}"
    render json: {
      success: false,
      error: "Failed to duplicate order item: #{e.message}"
    }, status: :unprocessable_entity
  end

  def rename
    return unless ensure_custom_item!
    return unless ensure_draft_order!

    new_name = rename_order_item_params[:variant_title].to_s.strip
    if new_name.blank?
      return render json: {
        success: false,
        error: "Name can't be blank"
      }, status: :unprocessable_entity
    end

    previous_name = @order_item.display_name
    @order_item.update!(variant_title: new_name)

    OrderActivityService.new(order: @order_item.order).log_custom_item_renamed(
      order_item: @order_item,
      previous_name: previous_name,
      actor: current_user
    )

    render json: {
      success: true,
      message: "Custom order item renamed successfully",
      order_item: {
        id: @order_item.id,
        display_name: @order_item.display_name,
        quantity: @order_item.quantity
      }
    }, status: :ok
  rescue => e
    Rails.logger.error "Error renaming order item #{@order_item.id}: #{e.message}"
    render json: {
      success: false,
      error: "Failed to rename order item: #{e.message}"
    }, status: :unprocessable_entity
  end

  private

  def set_order_item
    @order_item = OrderItem.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Order item not found" }, status: :not_found
  end

  def rename_order_item_params
    params.require(:order_item).permit(:variant_title)
  end

  def ensure_custom_item!
    return true if @order_item.is_custom?

    render json: {
      success: false,
      error: "Only custom order items can be changed this way"
    }, status: :unprocessable_entity
    false
  end

  def ensure_draft_order!
    return true if @order_item.order.draft?

    render json: {
      success: false,
      error: "Can only change custom items on draft orders"
    }, status: :unprocessable_entity
    false
  end
end
