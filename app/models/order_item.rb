class OrderItem < ApplicationRecord
  # Associations
  belongs_to :order
  belongs_to :product_variant, optional: true
  belongs_to :variant_mapping, optional: true

  # Delegations for convenience
  delegate :store, to: :order
  delegate :platform, to: :order

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price, :total, :discount_amount, :tax_amount,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Custom validations
  validate :mapping_matches_product_variant

  # Callbacks
  before_validation :auto_resolve_variant_associations, on: :create

  # Scopes
  scope :with_mappings, -> { joins(:variant_mapping) }
  scope :without_mappings, -> { where(variant_mapping: nil) }
  scope :requiring_shipping, -> { where(requires_shipping: true) }
  scope :by_external_variant, ->(variant_id) { where(external_variant_id: variant_id) }

  # Instance methods
  def display_name
    variant_title.present? ? "#{title} - #{variant_title}" : title
  end

  def has_variant_mapping?
    variant_mapping.present?
  end

  def can_fulfill?
    has_variant_mapping? && requires_shipping?
  end

  def line_total_with_tax
    total + tax_amount
  end

  def unit_price_with_tax
    return 0 if quantity.zero?
    line_total_with_tax / quantity
  end

  def resolve_variant_associations!(store_id: nil)
    store_id ||= order.store_id
    return unless external_variant_id.present?

    pv = ProductVariant
      .joins(:product)
      .where(products: { store_id: store_id })
      .find_by(external_variant_id: external_variant_id.to_s)

    self.product_variant = pv
    self.variant_mapping = pv&.variant_mapping
    # Don't save here - let the normal save process handle it
    # save! if changed?
  end

  def shopify_gid
    return nil unless platform == "shopify" || external_line_id.present?
    "gid://shopify/LineItem/#{external_line_id}"
  end

  def platform_product_url
    return nil unless product_variant&.product
    product_variant.product.platform_url
  end

  def artwork_preview_url(size: 500)
    variant_mapping&.artwork_preview_image(size: size)
  end

  def framed_preview_url(size: 500)
    variant_mapping&.framed_preview_url(size: size)
  end

  private

  def auto_resolve_variant_associations
    resolve_variant_associations!(store_id: order.store_id) if order
  end

  def mapping_matches_product_variant
    return unless variant_mapping && product_variant
    if variant_mapping.product_variant_id != product_variant_id
      errors.add(:variant_mapping, "does not match product_variant")
    end
  end
end
