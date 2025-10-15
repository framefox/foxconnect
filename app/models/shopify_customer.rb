class ShopifyCustomer < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :company, optional: true

  # Delegations to User
  delegate :email, :first_name, :last_name, :full_name, to: :user

  # Validations
  validates :external_shopify_id, presence: true, uniqueness: true
  validates :country_code, presence: true, inclusion: { in: CountryConfig.supported_countries }
  validates :country_code, uniqueness: { scope: :user_id, message: "already has a Shopify customer for this country" }

  # Scopes
  scope :for_country, ->(country_code) { where(country_code: country_code) }
end
