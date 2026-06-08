class StatementRunLineItem < ApplicationRecord
  belongs_to :statement_run
  belongs_to :order

  validates :order_id, presence: true, uniqueness: true
  validates :xero_invoice_id, presence: true
  validates :currency, presence: true
  validates :product_amount_cents, :shipping_amount_cents, :amount_cents,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  def product_amount
    product_amount_cents / 100.0
  end

  def shipping_amount
    shipping_amount_cents / 100.0
  end

  def amount
    amount_cents / 100.0
  end
end
