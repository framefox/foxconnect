class Store < ApplicationRecord
  # Include platform-specific concerns
  include ShopifySessionStorage
  include ShopifyIntegration
  include WixIntegration
  include SquarespaceIntegration

  # Associations
  belongs_to :user, optional: true
  has_many :products, dependent: :destroy
  has_many :product_variants, through: :products
  has_many :orders, dependent: :destroy

  # Core validations
  validates :name, :platform, presence: true

  # Ensure we always have a name for Shopify stores
  before_validation :ensure_name_from_platform

  # Platform enum - extensible for future platforms
  enum :platform, {
    shopify: "shopify",
    wix: "wix",
    squarespace: "squarespace"
  }

  # Scopes
  scope :active, -> { where(active: true) }
  scope :by_platform, ->(platform) { where(platform: platform) }

  # Platform-specific scopes
  scope :shopify_stores, -> { where(platform: :shopify) }
  scope :wix_stores, -> { where(platform: :wix) }
  scope :squarespace_stores, -> { where(platform: :squarespace) }

  # Override ShopifyApp's store method to ensure access_scopes are saved
  def self.store(session)
    store = find_or_initialize_by(shopify_domain: session.shop)
    store.platform = "shopify"  # Set platform first so callbacks work correctly
    store.shopify_token = session.access_token
    # Always use the current configured app scopes
    store.access_scopes = ShopifyApp.configuration.scope

    # Use shop domain as name if blank (we can fetch actual name later)
    if store.name.blank?
      store.name = session.shop
    end

    # Associate with current user if available
    if Thread.current[:current_user_id]
      store.user_id = Thread.current[:current_user_id]
    end

    store.save!
    # After successful connection, enqueue background job to fetch and persist the actual Shopify store name
    UpdateShopifyStoreNameJob.perform_later(store)
    store.id
  end

  # Platform-agnostic methods
  def sync_products!
    case platform
    when "shopify"
      sync_shopify_products!
    when "wix"
      sync_wix_products!
    when "squarespace"
      sync_squarespace_products!
    else
      Rails.logger.warn "Product sync not implemented for platform: #{platform}"
    end
  end

  def process_order!(order_data)
    case platform
    when "shopify"
      # Future: process_shopify_order!(order_data)
      Rails.logger.info "Processing Shopify order for store: #{name}"
    when "wix"
      # Future: process_wix_order!(order_data)
      Rails.logger.info "Processing Wix order for store: #{name}"
    when "squarespace"
      # Future: process_squarespace_order!(order_data)
      Rails.logger.info "Processing Squarespace order for store: #{name}"
    end
  end

  def platform_admin_url
    case platform
    when "shopify"
      shopify_admin_url
    when "wix"
      wix_admin_url
    when "squarespace"
      squarespace_admin_url
    end
  end

  def platform_display_name
    case platform
    when "shopify"
      "Shopify"
    when "wix"
      "Wix"
    when "squarespace"
      "Squarespace"
    else
      platform.humanize
    end
  end

  def display_identifier
    case platform
    when "shopify"
      shopify_domain
    when "wix"
      wix_site_id || name
    when "squarespace"
      squarespace_domain || name
    else
      name
    end
  end

  # Statistics methods
  def total_products_count
    products.count
  end

  def active_products_count
    products.active.count
  end

  def total_orders_count
    orders.count
  end

  def recent_orders_count
    orders.where(created_at: 7.days.ago..).count
  end

  private

  def ensure_name_from_platform
    # For Shopify stores, default name to the shopify_domain if blank
    if platform == "shopify" && (name.blank? || name.strip.empty?)
      self.name = shopify_domain.presence || "Shopify Store"
    end
  end

  def connected?
    case platform
    when "shopify"
      shopify_token.present?
    when "wix"
      wix_token.present?
    when "squarespace"
      squarespace_token.present?
    else
      false
    end
  end

  def last_sync_status
    return "never" unless last_sync_at
    return "recent" if last_sync_at > 1.hour.ago
    return "stale" if last_sync_at > 1.day.ago
    "old"
  end
end
