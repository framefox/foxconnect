class OrderItemsController < ApplicationController
  before_action :set_order_item, only: [ :remove_variant_mapping ]

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

  private

  def set_order_item
    @order_item = OrderItem.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: "Order item not found" }, status: :not_found
  end
end
