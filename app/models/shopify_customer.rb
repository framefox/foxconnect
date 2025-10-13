class ShopifyCustomer < ApplicationRecord
  has_many :stores, foreign_key: :shopify_customer_id, primary_key: :shopify_customer_id

  validates :shopify_customer_id, :email, presence: true
  validates :shopify_customer_id, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }

  def full_name
    "#{first_name} #{last_name}".strip.presence || email
  end
end
