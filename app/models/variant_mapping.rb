class VariantMapping < ApplicationRecord
  # Associations
  belongs_to :product_variant

  # Delegations for convenience
  delegate :product, to: :product_variant
  delegate :store, to: :product_variant

  # Validations
  validates :product_variant, presence: true, uniqueness: true
  validates :image_id, presence: true, numericality: { greater_than: 0 }
  validates :image_key, presence: true
  validates :frame_sku_id, presence: true, numericality: { greater_than: 0 }
  validates :frame_sku_code, presence: true
  validates :frame_sku_title, presence: true
  validates :cx, :cy, :cw, :ch, presence: true, numericality: { greater_than_or_equal_to: 0 }

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

  def artwork_preview_image(size: 1000)
    return nil unless cloudinary_id.present? && has_valid_crop? && image_width.present? && image_height.present?

    # Use the longest dimension for scaling calculation to match Cloudinary's "fit" behavior
    longest_dimension = [ image_width, image_height ].max

    # Generate Cloudinary URL with chained transformations
    Cloudinary::Utils.cloudinary_url(
      cloudinary_id,
      transformation: [
        # First transformation: scale the image to fit the desired size
        {
          width: size,
          crop: "fit"
        },
        # Second transformation: crop using scaled coordinates
        {
          width: (cw * size / longest_dimension).to_i,
          height: (ch * size / longest_dimension).to_i,
          x: (cx * size / longest_dimension).to_i,
          y: (cy * size / longest_dimension).to_i,
          crop: "crop"
        }
      ],
      quality: "auto",
      fetch_format: "auto"
    )
  end

  # Convenience methods for common sizes
  def artwork_preview_thumbnail
    artwork_preview_image(size: 200)
  end

  def artwork_preview_medium
    artwork_preview_image(size: 500)
  end

  def artwork_preview_large
    artwork_preview_image(size: 1000)
  end

  def framed_preview_url(size: 1000)
    return nil unless preview_url.present? && artwork_preview_image(size: size).present?

    # Get the artwork preview image URL
    artwork_url = artwork_preview_image(size: size)

    # Parse the preview URL to modify parameters
    uri = URI.parse(preview_url)
    params = URI.decode_www_form(uri.query || "")
    params_hash = params.to_h

    # Check if crop dimensions and art dimensions have matching orientation
    crop_is_landscape = cw >= ch

    # Get current art dimensions
    art_width_mm = params_hash["artWidthMM"]&.to_f
    art_height_mm = params_hash["artHeightMM"]&.to_f

    if art_width_mm && art_height_mm
      art_is_landscape = art_width_mm >= art_height_mm

      # If orientations don't match, flip the art dimensions
      if crop_is_landscape != art_is_landscape
        params_hash["artWidthMM"] = art_height_mm.to_s
        params_hash["artHeightMM"] = art_width_mm.to_s
      end
    end

    # Replace the artwork parameter and set maxPX to the size
    params_hash["artwork"] = artwork_url
    params_hash["maxPX"] = size.to_s

    # Rebuild the URL with the updated parameters
    uri.query = URI.encode_www_form(params_hash)
    uri.to_s
  end

  # Convenience methods for framed preview sizes
  def framed_preview_thumbnail
    framed_preview_url(size: 200)
  end

  def framed_preview_medium
    framed_preview_url(size: 500)
  end

  def framed_preview_large
    framed_preview_url(size: 1000)
  end
end
