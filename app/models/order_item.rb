class OrderItem < ApplicationRecord
  # Soft delete functionality
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Associations
  belongs_to :order
  belongs_to :product_variant, optional: true
  belongs_to :variant_mapping, optional: true
  has_many :fulfillment_line_items, dependent: :destroy
  has_many :fulfillments, through: :fulfillment_line_items

  # Money columns - custom accessors to avoid initialization issues
  # Note: Not using monetize automatic declarations to prevent currency initialization errors

  # Delegations for convenience
  delegate :store, to: :order
  delegate :platform, to: :order

  # Validations
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :price_cents, :total_cents, :discount_amount_cents, :tax_amount_cents,
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :production_cost_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Custom validations
  validate :mapping_matches_product_variant
  validate :variant_mapping_matches_order_country

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

  def country_matches_variant_mapping?
    return false unless variant_mapping && order&.country_code.present?
    variant_mapping.country_code == order.country_code
  end

  def can_fulfill?
    has_variant_mapping? && requires_shipping?
  end

  def fulfillable?
    product_variant&.fulfilment_active == true
  end

  def non_fulfillable?
    product_variant&.fulfilment_active == false
  end

  def unknown_product?
    product_variant.nil?
  end

  def line_total_with_tax
    total + tax_amount
  end

  def unit_price_with_tax
    return Money.new(0, order.currency) if quantity.zero?
    Money.new((line_total_with_tax.cents / quantity).to_i, order.currency)
  end

  def resolve_variant_associations!(store_id: nil)
    store_id ||= order.store_id
    return unless external_variant_id.present?

    pv = ProductVariant
      .joins(:product)
      .where(products: { store_id: store_id })
      .find_by(external_variant_id: external_variant_id.to_s)

    self.product_variant = pv

    # Create a copy of the default variant mapping for this order item
    # instead of sharing the same record
    # Only copy default mapping if country matches order's shipping country
    if pv && !self.variant_mapping && order.country_code.present?
      default_mapping = pv.default_variant_mapping(country_code: order.country_code)
      copy_default_variant_mapping_from(default_mapping) if default_mapping
    end

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

  # Fulfillment tracking methods
  def fulfilled_quantity
    fulfillment_line_items.sum(:quantity)
  end

  def unfulfilled_quantity
    quantity - fulfilled_quantity
  end

  def fully_fulfilled?
    fulfilled_quantity >= quantity
  end

  def partially_fulfilled?
    fulfilled_quantity.positive? && !fully_fulfilled?
  end

  # Soft delete methods
  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def active?
    deleted_at.nil?
  end

  # Money object accessors
  def price
    Money.new(price_cents || 0, order.currency)
  end

  def total
    Money.new(total_cents || 0, order.currency)
  end

  def discount_amount
    Money.new(discount_amount_cents || 0, order.currency)
  end

  def tax_amount
    Money.new(tax_amount_cents || 0, order.currency)
  end

  def production_cost
    Money.new(production_cost_cents || 0, order.currency)
  end

  # Create an independent copy of a variant mapping for this order item
  def copy_default_variant_mapping_from(default_mapping)
    return unless default_mapping && product_variant

    # Copy all attributes except id, timestamps, product_variant_id, and is_default
    copied_attributes = default_mapping.attributes.except(
      "id", "created_at", "updated_at", "product_variant_id", "is_default"
    )

    copied_mapping = VariantMapping.new(
      copied_attributes.merge(product_variant: product_variant)
    )

    self.variant_mapping = copied_mapping
    Rails.logger.info "Created independent variant mapping copy for order item: #{display_name}"
  rescue => e
    Rails.logger.error "Failed to copy variant mapping for order item #{id}: #{e.message}"
    # Don't fail the entire process if variant mapping copy fails
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

  def variant_mapping_matches_order_country
    return unless variant_mapping && order&.country_code.present?
    if variant_mapping.country_code != order.country_code
      errors.add(:variant_mapping, "country (#{variant_mapping.country_code}) does not match order shipping country (#{order.country_code})")
    end
  end
end
