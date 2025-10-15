class ShopifyCustomer < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :company, optional: true

  # Delegations to User
  delegate :email, :first_name, :last_name, :full_name, to: :user

  # Validations
  validates :external_shopify_id, presence: true, uniqueness: true
end
