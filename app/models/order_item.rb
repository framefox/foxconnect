class OrderItem < ApplicationRecord
  # Soft delete functionality
  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  # Custom item scopes
  scope :custom, -> { where(is_custom: true) }
  scope :store_synced, -> { where(is_custom: false) }

  # Associations
  belongs_to :order
  belongs_to :product_variant, optional: true
  belongs_to :variant_mapping, optional: true  # deprecated, for backward compat
  has_many :variant_mappings, dependent: :destroy  # new bundle-based approach
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
            presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: :is_custom?
  validates :production_cost_cents, presence: true, numericality: { greater_than_or_equal_to: 0 }, unless: :is_custom?
  validates :variant_title, presence: true, if: :is_custom?

  # Custom validations
  validate :mapping_matches_product_variant
  validate :variant_mapping_matches_order_country

  # Callbacks
  before_validation :auto_resolve_variant_associations, on: :create
  before_validation :set_default_cents_for_custom_items, if: :is_custom?
  after_create :copy_bundle_mappings_if_needed

  # Scopes
  scope :with_mappings, -> { joins(:variant_mapping) }
  scope :without_mappings, -> { where(variant_mapping: nil) }
  scope :requiring_shipping, -> { where(requires_shipping: true) }
  scope :by_external_variant, ->(variant_id) { where(external_variant_id: variant_id) }

  # Instance methods
  def display_name
    # Custom items only have variant_title, no title
    return variant_title if is_custom? && variant_title.present?
    variant_title.present? ? "#{title} - #{variant_title}" : title
  end

  def has_variant_mapping?
    variant_mappings.any? || variant_mapping.present?
  end

  def is_bundle?
    variant_mappings.count > 1
  end

  def slot_count
    bundle_slot_count || 1
  end

  def all_slots_filled?
    return true if variant_mapping.present? # old style
    
    variant_mappings.count == slot_count
  end

  def total_frame_cost
    return variant_mapping.frame_sku_cost if variant_mapping.present?
    
    variant_mappings.sum { |vm| vm.frame_sku_cost }
  end

  def country_matches_variant_mapping?
    mapping = effective_variant_mapping
    return false unless mapping && order&.country_code.present?
    mapping.country_code == order.country_code
  end

  def can_fulfill?
    has_variant_mapping? && requires_shipping?
  end

  def fulfillable?
    # Custom items are always fulfillable (they need variant mapping like regular items)
    return true if is_custom?
    product_variant&.fulfilment_active == true
  end

  def non_fulfillable?
    # Custom items are always fulfillable
    return false if is_custom?
    product_variant&.fulfilment_active == false
  end

  def unknown_product?
    # Custom items don't have product_variants, but they're not unknown
    return false if is_custom?
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

    # Note: Bundle mapping copying (for both single-slot and multi-slot) is handled
    # by the after_create callback :copy_bundle_mappings_if_needed
    # This ensures we have an order_item.id for the variant_mapping association
  end

  def shopify_gid
    return nil unless platform == "shopify" || external_line_id.present?
    "gid://shopify/LineItem/#{external_line_id}"
  end

  def platform_product_url
    return nil unless product_variant&.product
    product_variant.product.platform_url
  end

  # Returns the effective variant mapping, preferring the deprecated singular
  # but falling back to the first mapping from has_many :variant_mappings
  # This ensures backward compatibility while supporting the new bundle system
  def effective_variant_mapping
    variant_mapping || variant_mappings.order(:slot_position).first
  end

  def artwork_preview_url(size: 500)
    effective_variant_mapping&.artwork_preview_image(size: size)
  end

  def framed_preview_url(size: 500)
    effective_variant_mapping&.framed_preview_url(size: size)
  end

  # Serialize variant mappings for frontend (bundle support)
  def variant_mappings_for_frontend
    if variant_mappings.any?
      variant_mappings.order(:slot_position).map do |vm|
        {
          id: vm.id,
          slot_position: vm.slot_position,
          framed_preview_thumbnail: vm.framed_preview_thumbnail,
          frame_sku_cost_formatted: vm.frame_sku_cost_formatted,
          frame_sku_cost_dollars: vm.frame_sku_cost_dollars,
          frame_sku_title: vm.frame_sku_title,
          frame_sku_description: vm.frame_sku_description,
          frame_sku_code: vm.frame_sku_code,
          frame_sku_long: vm.frame_sku_long,
          frame_sku_short: vm.frame_sku_short,
          frame_sku_unit: vm.frame_sku_unit,
          image_filename: vm.image_filename,
          ch: vm.ch,
          cw: vm.cw,
          width: vm.width,
          height: vm.height,
          unit: vm.unit,
          dimensions_display: vm.dimensions_display
        }
      end
    else
      []
    end
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

  # DEPRECATED: This method had bugs (didn't clear bundle_id, didn't set order_item_id)
  # Use copy_bundle_mappings_from_variant instead, which handles both single-slot and multi-slot bundles correctly.
  # Kept for backward compatibility but no longer called internally.
  def copy_default_variant_mapping_from(default_mapping)
    Rails.logger.warn "DEPRECATED: copy_default_variant_mapping_from is deprecated. Use copy_bundle_mappings_from_variant instead."
    return unless default_mapping && product_variant

    # Fixed version: properly exclude bundle_id and set order_item_id
    copied_attributes = default_mapping.attributes.except(
      "id", "created_at", "updated_at", "product_variant_id", "is_default", "bundle_id", "order_item_id"
    )

    copied_mapping = VariantMapping.new(
      copied_attributes.merge(
        product_variant: product_variant,
        is_default: false,           # Order item mappings are never defaults
        bundle_id: nil,              # Clear bundle association
        order_item_id: self.id,      # Associate with this order item (if persisted)
        slot_position: 1             # Single-slot items use position 1
      )
    )

    # Use the new has_many association if we have an id, otherwise fall back to deprecated belongs_to
    if self.persisted?
      copied_mapping.save!
    else
      self.variant_mapping = copied_mapping
    end
    
    Rails.logger.info "Created independent variant mapping copy for order item: #{display_name}"
  rescue => e
    Rails.logger.error "Failed to copy variant mapping for order item #{id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    # Don't fail the entire process if variant mapping copy fails
  end

  # Copy bundle mappings from variant (for both single-slot and multi-slot bundles)
  def copy_bundle_mappings_from_variant
    return unless product_variant&.bundle
    
    # Filter mappings by the order's country code
    country_code = order.country_code
    template_mappings = product_variant.bundle.variant_mappings.for_country(country_code)
    
    return unless template_mappings.any?
    
    # Snapshot the actual count of filled slots (only copy filled slots, not empty ones)
    self.bundle_slot_count = template_mappings.count
    
    template_mappings.each do |template|
      copied_mapping = template.dup
      copied_mapping.bundle_id = nil           # Clear bundle association (this is an order copy)
      copied_mapping.order_item_id = self.id   # Associate with this order item
      copied_mapping.slot_position = template.slot_position
      copied_mapping.is_default = false        # Order item mappings are never defaults
      copied_mapping.save!
    end
    
    # Save the updated bundle_slot_count
    save!
    
    Rails.logger.info "Copied #{template_mappings.count} bundle mapping(s) for order item #{id} (#{display_name})"
  rescue => e
    Rails.logger.error "Failed to copy bundle mappings for order item #{id}: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    # Don't fail the entire process if bundle mapping copy fails
  end

  private

  def set_default_cents_for_custom_items
    # Set all monetary values to 0 for custom items
    self.price_cents ||= 0
    self.total_cents ||= 0
    self.discount_amount_cents ||= 0
    self.tax_amount_cents ||= 0
    self.production_cost_cents ||= 0
  end

  def auto_resolve_variant_associations
    # Skip auto-resolution for custom items
    return if is_custom?
    resolve_variant_associations!(store_id: order.store_id) if order
  end

  def copy_bundle_mappings_if_needed
    # Skip for custom items
    return if is_custom?
    
    # Copy bundle mappings for ALL bundles (single-slot and multi-slot)
    # This ensures consistent handling and proper order_item_id association
    return unless product_variant&.bundle
    return unless product_variant.bundle.variant_mappings.for_country(order.country_code).any?
    
    # Copy the bundle mappings
    copy_bundle_mappings_from_variant
  end

  def mapping_matches_product_variant
    # Skip validation for custom items (they don't need to match product_variant)
    return if is_custom?
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
