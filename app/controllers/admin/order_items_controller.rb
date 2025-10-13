class Admin::OrderItemsController < Admin::ApplicationController
  before_action :set_order_item, only: [ :remove_variant_mapping, :soft_delete, :restore ]

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

  private

  def set_order_item
    @order_item = OrderItem.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Order item not found" }, status: :not_found
  end
end
