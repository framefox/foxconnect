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

  def fulfillable?
    product_variant&.fulfilment_active == true
  end

  def non_fulfillable?
    product_variant&.fulfilment_active == false
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

    # Create a copy of the default variant mapping for this order item
    # instead of sharing the same record
    if pv&.default_variant_mapping && !self.variant_mapping
      copy_default_variant_mapping_from(pv.default_variant_mapping)
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
end
