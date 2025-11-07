class SavedItem < ApplicationRecord
  belongs_to :user
  belongs_to :custom_print_size, optional: true

  validates :user_id, presence: true
  validates :frame_sku_id, presence: true, uniqueness: { scope: :user_id }

  scope :recent_first, -> { order(created_at: :desc) }
end

