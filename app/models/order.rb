class Order < ApplicationRecord
  include AASM

  # Associations
  belongs_to :store
  has_many :order_items, dependent: :destroy
  has_many :active_order_items, -> { active }, class_name: "OrderItem"
  has_one :shipping_address, dependent: :destroy

  # Delegations for convenience
  delegate :platform, to: :store

  # State Machine
  aasm do
    state :draft, initial: true
    state :awaiting_production
    state :in_production
    state :cancelled

    event :submit do
      transitions from: [ :draft, :start_production ], to: :awaiting_production
    end

    event :start_production do
      transitions from: :awaiting_production, to: :in_production
    end

    event :cancel do
      transitions from: [ :draft, :awaiting_production, :in_production ], to: :cancelled
    end

    event :reopen do
      transitions from: :cancelled, to: :draft
    end
  end

  # Validations
  validates :external_id, presence: true
  validates :external_id, uniqueness: { scope: :store_id }
  validates :currency, presence: true, length: { is: 3 }
  validates :subtotal_price, :total_discounts, :total_shipping, :total_tax, :total_price,
            presence: true, numericality: { greater_than_or_equal_to: 0 }

  # Enums
  enum :financial_status, {
    pending: "pending",
    authorized: "authorized",
    paid: "paid",
    partially_paid: "partially_paid",
    refunded: "refunded",
    voided: "voided"
  }, validate: false

  enum :fulfillment_status, {
    unfulfilled: "unfulfilled",
    partial: "partial",
    fulfilled: "fulfilled",
    restocked: "restocked",
    cancelled: "cancelled"
  }, validate: false

  # Scopes
  scope :by_platform, ->(platform) { joins(:store).where(stores: { platform: platform }) }
  scope :processed, -> { where.not(processed_at: nil) }
  scope :pending_fulfillment, -> { where(fulfillment_status: [ "unfulfilled", "partial" ]) }
  scope :paid_orders, -> { where(financial_status: [ "paid", "partially_paid" ]) }

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

  def fulfillable_items
    order_items.joins(:product_variant).where(product_variants: { fulfilment_active: true })
  end

  def non_fulfillable_items
    order_items.joins(:product_variant).where(product_variants: { fulfilment_active: false })
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
end
