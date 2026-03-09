class InvoiceRunLineItem < ApplicationRecord
  belongs_to :invoice_run

  validates :shopify_order_id, presence: true, uniqueness: true
  validates :shopify_order_name, presence: true
  validates :currency, presence: true

  def amount
    amount_cents / 100.0
  end
end
