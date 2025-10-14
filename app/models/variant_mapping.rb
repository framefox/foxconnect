class VariantMapping < ApplicationRecord
  # Money handling
  monetize :frame_sku_cost_cents

  # Associations
  belongs_to :product_variant
  has_many :order_items, dependent: :nullify

  # Delegations for convenience
  delegate :product, to: :product_variant
  delegate :store, to: :product

  # Validations
  validates :product_variant, presence: true
  validates :image_id, presence: true, numericality: { greater_than: 0 }
  validates :image_key, presence: true
  validates :frame_sku_id, presence: true, numericality: { greater_than: 0 }
  validates :frame_sku_code, presence: true
  validates :frame_sku_title, presence: true
  validates :frame_sku_cost_cents, presence: true, numericality: { greater_than: 0 }
  validates :cx, :cy, :cw, :ch, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :is_default, uniqueness: { scope: :product_variant_id }, if: :is_default?

  # Callbacks
  before_destroy :handle_default_removal
  after_create :set_as_default_if_first

  # Scopes
  scope :by_frame_sku, ->(sku_code) { where(frame_sku_code: sku_code) }
  scope :by_image, ->(image_id) { where(image_id: image_id) }
  scope :with_preview, -> { where.not(preview_url: nil) }
  scope :defaults, -> { where(is_default: true) }
  scope :non_defaults, -> { where(is_default: false) }
  scope :for_order_items, -> { joins(:order_items) }
  scope :not_for_order_items, -> { where.not(id: OrderItem.select(:variant_mapping_id).where.not(variant_mapping_id: nil)) }

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
      title: frame_sku_title,
      cost: frame_sku_cost
    }
  end

  # Helper method to get the cost as a formatted currency string
  def frame_sku_cost_formatted
    frame_sku_cost.format
  end

  # Helper method to get the cost in dollars (for API responses)
  def frame_sku_cost_dollars
    frame_sku_cost.to_f
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
    base_preview_url = uri.to_s

    # Wrap with Cloudinary fetch and pad onto a #eee background at 115% of size
    final_canvas = (size * 1.15).to_i
    Cloudinary::Utils.cloudinary_url(
      base_preview_url,
      type: "fetch",
      transformation: [
        { effect: "shadow:#{(size / 5).to_i}", x: (size / 150).to_i, y: (size / 150).to_i, color: "#ddd" },
        { effect: "shadow:#{(size / 5).to_i}", x: -(size / 75).to_i, y: -(size / 75).to_i, color: "#ddd" },
        {
          width: final_canvas,
          height: final_canvas,
          background: "rgb:f4f4f4",
          crop: "lpad",
          gravity: "center"
        }

      ],
      quality: "auto",
      fetch_format: "auto"
    )
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

  # Sync the framed preview image to the Shopify variant
  def sync_to_shopify_variant(size: 1000, alt_text: nil)
    return { success: false, error: "Store is not a Shopify store" } unless store.shopify?
    return { success: false, error: "No framed preview available" } unless framed_preview_url(size: size).present?
    return { success: false, error: "No external variant ID" } unless product_variant.external_variant_id.present?

    image_url = framed_preview_url(size: size)
    shopify_variant_id = product_variant.external_variant_id
    shopify_product_id = product_variant.product.external_id

    # Use the frame SKU title as alt text/title if none provided
    alt_text ||= frame_sku_title

    store.sync_variant_image(
      shopify_variant_id: shopify_variant_id,
      image_url: image_url,
      shopify_product_id: shopify_product_id,
      alt_text: alt_text
    )
  end

  private

  # Automatically set as default if this is the first variant mapping for the product variant
  # and it's not associated with an order item
  def set_as_default_if_first
    return if order_items.exists? # Don't set order item mappings as default
    return if product_variant.variant_mappings.defaults.exists? # Already has a default
    return if is_default == false # Respect explicitly set is_default: false

    update_column(:is_default, true)
    Rails.logger.info "Set variant mapping #{id} as default for product variant #{product_variant_id}"
  end

  # Handle removal of default variant mapping
  def handle_default_removal
    return unless is_default?

    # When a default variant mapping is deleted, we don't automatically promote another one
    # This allows the product variant to have "no default" state
    Rails.logger.info "Removed default variant mapping #{id} for product variant #{product_variant_id} - no replacement set"
  end
end
