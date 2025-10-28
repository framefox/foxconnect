class Image < ApplicationRecord
  # Associations
  has_many :variant_mappings, dependent: :nullify

  # Validations
  validates :external_image_id, presence: true, numericality: { greater_than: 0 }
  validates :image_key, presence: true
  validates :cx, :cy, :cw, :ch, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Instance methods
  def crop_coordinates
    {
      x: cx,
      y: cy,
      width: cw,
      height: ch
    }
  end

  def crop_coordinates=(coords)
    self.cx = coords[:x] || coords["x"]
    self.cy = coords[:y] || coords["y"]
    self.cw = coords[:width] || coords["width"]
    self.ch = coords[:height] || coords["height"]
  end

  def has_valid_crop?
    cx.present? && cy.present? && cw.present? && ch.present? &&
      cx >= 0 && cy >= 0 && cw > 0 && ch > 0
  end
end
