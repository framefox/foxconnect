class BorderMapping < ApplicationRecord
  belongs_to :store

  validates :paper_type_id, presence: true, uniqueness: { scope: :store_id }
  validates :border_width_mm, presence: true, numericality: { greater_than: 0 }
end
