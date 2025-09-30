class Product < ApplicationRecord
  # Associations
  belongs_to :store
  has_many :product_variants, dependent: :destroy

  # Delegations for convenience
  delegate :platform, to: :store
  delegate :shopify_domain, to: :store, allow_nil: true

  # Validations
  validates :title, :handle, :external_id, presence: true
  validates :handle, uniqueness: true
  validates :external_id, uniqueness: { scope: :store_id }

  # Enums
  enum :status, { draft: "draft", active: "active", archived: "archived" }

  # Scopes
  scope :active, -> { where(status: "active") }
  scope :published, -> { where.not(published_at: nil) }
  scope :by_platform, ->(platform) { joins(:store).where(stores: { platform: platform }) }
  scope :by_vendor, ->(vendor) { where(vendor: vendor) }
  scope :by_type, ->(type) { where(product_type: type) }

  # Callbacks
  before_validation :generate_handle, if: -> { handle.blank? && title.present? }

  # Methods
  def has_variants?
    product_variants.count > 1
  end

  def default_variant
    product_variants.order(:position).first
  end

  def price_range
    return [ 0, 0 ] if product_variants.empty?

    prices = product_variants.pluck(:price)
    [ prices.min, prices.max ]
  end

  def min_price
    price_range.first
  end

  def max_price
    price_range.last
  end

  def price_varies?
    min_price != max_price
  end

  def compare_at_price_range
    return [ nil, nil ] if product_variants.empty?

    compare_prices = product_variants.where.not(compare_at_price: nil).pluck(:compare_at_price)
    return [ nil, nil ] if compare_prices.empty?

    [ compare_prices.min, compare_prices.max ]
  end

  def available_for_sale?
    product_variants.any?(&:available_for_sale?)
  end

  def shopify_gid
    return nil unless platform == "shopify"
    "gid://shopify/Product/#{external_id}"
  end

  def platform_url
    case store.platform
    when "shopify"
      "https://#{store.shopify_domain}/admin/products/#{external_id}"
    when "squarespace"
      # Future implementation
      nil
    when "wix"
      # Future implementation
      nil
    end
  end

  # Helper method to check if product has variant mappings that can be synced
  def has_variant_mappings?
    product_variants.joins(:variant_mapping).exists?
  end

  # Get count of variant mappings for this product
  def variant_mappings_count
    VariantMapping.joins(:product_variant)
                  .where(product_variants: { product_id: id })
                  .count
  end

  # Get count of active variants for fulfillment
  def active_variants_count
    product_variants.where(fulfilment_active: true).count
  end

  # Get total variants count
  def total_variants_count
    product_variants.count
  end

  private

  def generate_handle
    self.handle = title.parameterize
  end
end
