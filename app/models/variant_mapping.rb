class VariantMapping < ApplicationRecord
  # Associations
  belongs_to :product_variant

  # Delegations for convenience
  delegate :product, to: :product_variant
  delegate :store, to: :product_variant

  # Validations
  validates :product_variant, presence: true
  validates :image_id, presence: true, numericality: { greater_than: 0 }
  validates :image_key, presence: true
  validates :frame_sku_id, presence: true, numericality: { greater_than: 0 }
  validates :frame_sku_code, presence: true
  validates :frame_sku_title, presence: true
  validates :cx, :cy, :cw, :ch, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :preview_url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }

  # Scopes
  scope :by_frame_sku, ->(sku_code) { where(frame_sku_code: sku_code) }
  scope :by_image, ->(image_id) { where(image_id: image_id) }
  scope :with_preview, -> { where.not(preview_url: nil) }

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

  def frame_info
    {
      id: frame_sku_id,
      code: frame_sku_code,
      title: frame_sku_title
    }
  end

  def image_info
    {
      id: image_id,
      key: image_key
    }
  end

  def display_name
    "#{product_variant.display_name} → #{frame_sku_title}"
  end

  def crop_aspect_ratio
    return nil unless has_valid_crop?
    cw.to_f / ch.to_f
  end
end
