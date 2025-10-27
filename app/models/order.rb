class Order < ApplicationRecord
  include AASM

  # Associations
  belongs_to :store
  has_many :order_items, dependent: :destroy
  has_many :active_order_items, -> { active }, class_name: "OrderItem"
  has_one :shipping_address, dependent: :destroy
  has_many :order_activities, dependent: :destroy
  has_many :fulfillments, dependent: :destroy

  # Money columns - custom accessors to avoid initialization issues
  # Note: Not using monetize automatic declarations to prevent currency initialization errors

  # Delegations for convenience
  delegate :platform, to: :store

  # State Machine
  aasm do
    state :draft, initial: true
    state :in_production
    state :cancelled
    state :fulfilled

    event :submit do
      transitions from: :draft, to: :in_production,
                  guard: :all_items_have_variant_mappings?
    end

    event :cancel do
      transitions from: [ :draft ], to: :cancelled
    end

    event :reopen do
      transitions from: :cancelled, to: :draft
    end

    event :fulfill do
      transitions from: :in_production, to: :fulfilled,
                  guard: :fully_fulfilled?
    end

    after_all_transitions :log_state_change_activity
  end

  # Validations
  validates :external_id, presence: true
  validates :external_id, uniqueness: { scope: :store_id }
  validates :uid, presence: true, uniqueness: true
  validates :currency, presence: true, length: { is: 3 }
  validates :country_code, inclusion: { in: CountryConfig.supported_countries }, allow_nil: true
  validates :subtotal_price_cents, :total_discounts_cents, :total_shipping_cents, :total_tax_cents, :total_price_cents,
            presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :production_subtotal_cents, :production_shipping_cents, :production_total_cents,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Callbacks
  before_validation :generate_uid, on: :create

  # Scopes
  scope :by_platform, ->(platform) { joins(:store).where(stores: { platform: platform }) }
  scope :processed, -> { where.not(processed_at: nil) }

  # Instance methods
  def display_name
    name.presence || "##{external_number || external_id}"
  end

  def customer_name
    return nil unless shipping_address
    shipping_address.name.presence || "#{shipping_address.first_name} #{shipping_address.last_name}".strip
  end

  def total_items
    order_items.sum(:quantity)
  end

  def has_variant_mappings?
    order_items.joins(:variant_mapping).exists?
  end

  def all_items_have_variant_mappings?
    return false if active_order_items.empty?
    return false if fulfillable_items.none? # Must have at least one fulfillable item
    fulfillable_items.where(variant_mapping_id: nil).none?
  end

  def fulfillable_items
    active_order_items.joins(:product_variant).where(product_variants: { fulfilment_active: true })
  end

  def non_fulfillable_items
    active_order_items.joins(:product_variant).where(product_variants: { fulfilment_active: false })
  end

  def platform_url
    case store.platform
    when "shopify"
      "https://#{store.shopify_domain}/admin/orders/#{external_id}"
    when "squarespace"
      # Future implementation
      nil
    when "wix"
      # Future implementation
      nil
    end
  end

  def shopify_gid
    return nil unless store.platform == "shopify"
    "gid://shopify/Order/#{external_id}"
  end

  def processed?
    processed_at.present?
  end

  def platform_cancelled?
    cancelled_at.present?
  end

  def closed?
    closed_at.present?
  end

  # Activity logging helpers
  def log_activity(activity_type:, title:, description: nil, metadata: {}, actor: nil, occurred_at: Time.current)
    OrderActivityService.new(order: self).log_activity(
      activity_type: activity_type,
      title: title,
      description: description,
      metadata: metadata,
      actor: actor,
      occurred_at: occurred_at
    )
  end

  def recent_activities(limit = 10)
    order_activities.recent.limit(limit)
  end

  # Fulfillment methods
  def fulfillment_status
    return :unfulfilled if fulfillments.none?
    return :fulfilled if fully_fulfilled?
    :partially_fulfilled
  end

  def fulfilled_items_count
    fulfillments.joins(:fulfillment_line_items).sum("fulfillment_line_items.quantity")
  end

  def unfulfilled_items_count
    total_items - fulfilled_items_count
  end

  def partially_fulfilled?
    fulfillments.any? && !fully_fulfilled?
  end

  def fully_fulfilled?
    return false if active_order_items.none?
    active_order_items.all?(&:fully_fulfilled?)
  end

  # Country configuration helpers
  def country_config
    return nil unless country_code.present?
    @country_config ||= CountryConfig.for_country(country_code)
  end

  def fulfillable_country?
    CountryConfig.supported?(country_code)
  end

  def country_name
    country_config&.dig("country_name") || country_code
  end

  # Payment methods
  def payment_captured?
    production_paid_at.present?
  end

  def mark_payment_captured!(timestamp = Time.current)
    return false if payment_captured? # Idempotency check
    update(production_paid_at: timestamp)
  end

  # Money object accessors
  def subtotal_price
    Money.new(subtotal_price_cents || 0, currency)
  end

  def total_discounts
    Money.new(total_discounts_cents || 0, currency)
  end

  def total_shipping
    Money.new(total_shipping_cents || 0, currency)
  end

  def total_tax
    Money.new(total_tax_cents || 0, currency)
  end

  def total_price
    Money.new(total_price_cents || 0, currency)
  end

  def production_subtotal
    Money.new(production_subtotal_cents || 0, currency)
  end

  def production_shipping
    Money.new(production_shipping_cents || 0, currency)
  end

  def production_total
    Money.new(production_total_cents || 0, currency)
  end

  # Use UID in URLs instead of ID
  def to_param
    uid
  end

  private

  def generate_uid
    return if uid.present?

    # Generate random 8-digit number (10000000 to 99999999)
    loop do
      self.uid = rand(10000000..99999999).to_s
      break unless Order.exists?(uid: uid)
    end
  end

  def log_state_change_activity
    OrderActivityService.new(order: self).log_state_change(
      from_state: aasm.from_state,
      to_state: aasm.to_state,
      event: aasm.current_event
    )
  end
end
