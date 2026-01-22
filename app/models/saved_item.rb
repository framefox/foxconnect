class SavedItem < ApplicationRecord
  belongs_to :organization
  belongs_to :custom_print_size, optional: true

  validates :organization_id, presence: true
  validates :frame_sku_id, presence: true, uniqueness: { scope: :organization_id }

  scope :recent_first, -> { order(created_at: :desc) }
end
