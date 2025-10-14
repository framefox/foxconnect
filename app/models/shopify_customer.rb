class ShopifyCustomer < ApplicationRecord
  # Associations
  # Changed from shopify_customer_id to id to match the foreign key in stores table
  # The stores.shopify_customer_id actually references shopify_customers.id, not shopify_customers.external_shopify_id
  has_many :stores, foreign_key: :shopify_customer_id, primary_key: :id
  belongs_to :company, optional: true

  # Validations
  validates :external_shopify_id, :email, presence: true
  validates :external_shopify_id, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  def full_name
    "#{first_name} #{last_name}".strip.presence || email
  end
end
