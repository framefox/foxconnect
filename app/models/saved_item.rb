class SavedItem < ApplicationRecord
  belongs_to :user

  validates :user_id, presence: true
  validates :frame_sku_id, presence: true, uniqueness: { scope: :user_id }

  scope :recent_first, -> { order(created_at: :desc) }
end

