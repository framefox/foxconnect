class Company < ApplicationRecord
  # Associations
  has_many :shopify_customers, dependent: :nullify

  # Callbacks
  before_validation :normalize_shopify_ids

  # Validations
  validates :company_name, presence: true
  validates :shopify_company_id, presence: true, uniqueness: true
  validates :shopify_company_location_id, presence: true
  validates :shopify_company_contact_id, presence: true

  # Scopes
  scope :ordered_by_name, -> { order(:company_name) }

  # Instance methods
  def to_s
    company_name
  end

  private

  # Strip gid://shopify/ prefix if present, keep only the numeric ID
  def normalize_shopify_ids
    self.shopify_company_id = extract_id_from_gid(shopify_company_id) if shopify_company_id.present?
    self.shopify_company_location_id = extract_id_from_gid(shopify_company_location_id) if shopify_company_location_id.present?
    self.shopify_company_contact_id = extract_id_from_gid(shopify_company_contact_id) if shopify_company_contact_id.present?
  end

  def extract_id_from_gid(value)
    # If it's a full GID like "gid://shopify/Company/123", extract just "123"
    # If it's already just a number, return as-is
    value.to_s.split("/").last
  end
end
