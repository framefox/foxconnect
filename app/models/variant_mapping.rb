class VariantMapping < ApplicationRecord
  # Money handling
  monetize :frame_sku_cost_cents

  # Associations
  belongs_to :product_variant
  belongs_to :image, optional: true
  has_many :order_items, dependent: :nullify

  # Delegations for convenience
  delegate :product, to: :product_variant
  delegate :store, to: :product

  # Delegate image fields to maintain backward compatibility with frontend
  delegate :external_image_id, :image_key, :cloudinary_id, :image_width, :image_height,
           :image_filename, :cx, :cy, :cw, :ch, to: :image, prefix: false, allow_nil: true

  # Validations
  validates :product_variant, presence: true
  validates :frame_sku_id, presence: true, numericality: { greater_than: 0 }
  validates :frame_sku_code, presence: true
  validates :frame_sku_title, presence: true
  validates :frame_sku_cost_cents, presence: true, numericality: { greater_than: 0 }
  validates :country_code, presence: true, inclusion: { in: CountryConfig.supported_countries }
  validates :is_default, uniqueness: { scope: [ :product_variant_id, :country_code ] }, if: :is_default?

  # Callbacks
  before_validation :calculate_dimensions_from_frame_sku
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

  # Standard print sizes
  STD_SIZES = [
    { title: "A5", short: 148, long: 210, unit: "mm" },
    { title: "A4", short: 210, long: 297, unit: "mm" },
    { title: "A3", short: 297, long: 420, unit: "mm" },
    { title: "A2", short: 420, long: 594, unit: "mm" },
    { title: "A1", short: 594, long: 841, unit: "mm" },
    { title: "A0", short: 841, long: 1189, unit: "mm" },
    { title: "B0", short: 1000, long: 1414, unit: "mm" }
  ].freeze

  # Instance methods
  def crop_coordinates
    return nil unless image.present?
    image.crop_coordinates
  end

  def crop_coordinates=(coords)
    # This will be handled when creating/updating the image association
    # Keeping for backward compatibility
    if image.present?
      image.crop_coordinates = coords
    end
  end

  def has_valid_crop?
    image.present? && image.has_valid_crop?
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
    return nil unless image.present?
    {
      id: image.external_image_id,
      key: image.image_key
    }
  end

  # Maintain backward compatibility - return external_image_id as image_id
  def image_id
    image&.external_image_id
  end

  def display_name
    "#{product_variant.display_name} → #{frame_sku_title}"
  end

  def country_config
    @country_config ||= CountryConfig.for_country(country_code)
  end

  def country_name
    country_config&.dig("country_name") || country_code
  end

  def crop_aspect_ratio
    return nil unless has_valid_crop?
    cw.to_f / ch.to_f
  end

  def dimensions_display
    base = "#{"%g" % ("%.2f" % width)} x #{"%g" % ("%.2f" % height)}#{unit_s}"

    # Check if dimensions match a standard size
    std_size = find_matching_standard_size
    std_size ? "#{base} (#{std_size})" : base
  end

  def find_matching_standard_size
    return nil unless width.present? && height.present? && unit == "mm"

    STD_SIZES.find do |size|
      # Check both orientations (portrait and landscape)
      # Allow small tolerance for rounding
      tolerance = 1.0 # 1mm tolerance

      (width - size[:short]).abs < tolerance && (height - size[:long]).abs < tolerance ||
      (width - size[:long]).abs < tolerance && (height - size[:short]).abs < tolerance
    end&.dig(:title)
  end

  def unit_s
    unit == "in" ? '"' : unit
  end

  # Convert width to millimeters
  def width_mm
    return nil unless width.present? && unit.present?
    convert_to_mm(width)
  end

  # Convert height to millimeters
  def height_mm
    return nil unless height.present? && unit.present?
    convert_to_mm(height)
  end

  def is_square?
    width == height
  end

  def artwork_preview_image(size: 1000)
    return nil unless image.present? && image.cloudinary_id.present? && has_valid_crop? && image.image_width.present? && image.image_height.present?

    # Use the longest dimension for scaling calculation to match Cloudinary's "fit" behavior
    longest_dimension = [ image.image_width, image.image_height ].max

    # Generate Cloudinary URL with chained transformations
    Cloudinary::Utils.cloudinary_url(
      image.cloudinary_id,
      transformation: [
        # First transformation: scale the image to fit the desired size
        {
          width: size,
          crop: "fit"
        },
        # Second transformation: crop using scaled coordinates
        {
          width: (image.cw * size / longest_dimension).to_i,
          height: (image.ch * size / longest_dimension).to_i,
          x: (image.cx * size / longest_dimension).to_i,
          y: (image.cy * size / longest_dimension).to_i,
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

    # Use variant_mapping dimensions directly - width and height are already correctly oriented
    if width_mm && height_mm
      params_hash["artWidthMM"] = width_mm.to_s
      params_hash["artHeightMM"] = height_mm.to_s
    end

    # Replace the artwork parameter and set maxPX to the size
    params_hash["artwork"] = artwork_url
    params_hash["maxPX"] = is_square? ? (size * 0.85).to_i.to_s : size.to_s

    # Rebuild the URL with the updated parameters
    uri.query = URI.encode_www_form(params_hash)
    base_preview_url = uri.to_s

    # Get background color from store settings, fallback to default
    bg_colour = store&.mockup_bg_colour || "f4f4f4"
    # Calculate shadow color (darker shade of background)
    shadow_colour = darken_hex_color(bg_colour, 23)

    # Wrap with Cloudinary fetch and pad onto a background at 120% of size
    final_canvas = (size * 1.2).to_i
    Cloudinary::Utils.cloudinary_url(
      base_preview_url,
      type: "fetch",
      transformation: [
        { effect: "shadow:#{(size / 5).to_i}", x: (size / 150).to_i, y: (size / 150).to_i, color: shadow_colour },
        { effect: "shadow:#{(size / 5).to_i}", x: -(size / 75).to_i, y: -(size / 75).to_i, color: shadow_colour },
        {
          width: final_canvas,
          height: final_canvas,
          background: "rgb:#{bg_colour}",
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

  # Darken a hex color by a specified amount
  # Example: darken_hex_color("f4f4f4", 23) => "#dddddd"
  def darken_hex_color(hex, amount)
    # Remove # if present and ensure we have 6 characters
    hex = hex.to_s.gsub("#", "")

    # Parse hex to RGB
    r = hex[0..1].to_i(16)
    g = hex[2..3].to_i(16)
    b = hex[4..5].to_i(16)

    # Darken by subtracting the amount (ensure we don't go below 0)
    r = [ r - amount, 0 ].max
    g = [ g - amount, 0 ].max
    b = [ b - amount, 0 ].max

    # Convert back to hex with # prefix
    "#%02x%02x%02x" % [ r, g, b ]
  end

  # Convert a dimension to millimeters based on the unit
  def convert_to_mm(dimension)
    case unit
    when "mm"
      dimension.to_f
    when "cm"
      dimension.to_f * 10
    when "in"
      dimension.to_f * 25.4
    else
      dimension.to_f
    end
  end

  # Calculate width, height, and unit from frame_sku dimensions based on crop orientation
  def calculate_dimensions_from_frame_sku
    # Skip calculation if dimensions are already explicitly set (custom size override)
    return if width.present? && height.present? && unit.present?

    # Only calculate if we have the necessary frame_sku values and crop dimensions
    return unless frame_sku_long.present? && frame_sku_short.present? && cw.present? && ch.present?

    # Copy unit directly from frame_sku_unit
    self.unit = frame_sku_unit if frame_sku_unit.present?

    # Determine orientation based on crop dimensions
    # If crop is landscape/square (width >= height), use long as width
    # If crop is portrait (height > width), flip the dimensions
    if cw >= ch
      # Landscape or square orientation
      self.width = frame_sku_long
      self.height = frame_sku_short
    else
      # Portrait orientation - flip the dimensions
      self.width = frame_sku_short
      self.height = frame_sku_long
    end
  end

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
