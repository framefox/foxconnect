class Fulfillment < ApplicationRecord
  # Associations
  belongs_to :order
  has_many :fulfillment_line_items, dependent: :destroy
  has_many :order_items, through: :fulfillment_line_items

  # Validations
  validates :shopify_fulfillment_id, uniqueness: true, allow_nil: true
  validates :status, presence: true

  # Scopes
  scope :successful, -> { where(status: %w[success pending]) }
  scope :recent, -> { order(fulfilled_at: :desc, created_at: :desc) }

  # Helper methods
  def display_status
    status&.humanize || "Unknown"
  end

  def tracking_info_present?
    tracking_number.present? || tracking_url.present?
  end

  def carrier_and_tracking
    return nil unless tracking_info_present?

    parts = []
    parts << tracking_company if tracking_company.present?
    parts << tracking_number if tracking_number.present?
    parts.join(" - ")
  end

  def item_count
    fulfillment_line_items.sum(:quantity)
  end
end

