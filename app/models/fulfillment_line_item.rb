class FulfillmentLineItem < ApplicationRecord
  # Associations
  belongs_to :fulfillment
  belongs_to :order_item

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validate :quantity_not_exceeds_order_item_quantity

  private

  def quantity_not_exceeds_order_item_quantity
    return unless order_item && quantity

    if quantity > order_item.quantity
      errors.add(:quantity, "cannot exceed order item quantity (#{order_item.quantity})")
    end
  end
end

