class Store < ApplicationRecord
  include ShopifyApp::ShopSessionStorage

  # Associations
  has_many :products, dependent: :destroy
  has_many :product_variants, through: :products
  # has_many :orders, dependent: :destroy (will be implemented in Phase 3)

  validates :name, :platform, :shopify_domain, presence: true
  validates :shopify_domain, uniqueness: true

  enum :platform, {
    shopify: "shopify"
    # Future platforms can be added here: woocommerce: 'woocommerce', etsy: 'etsy'
  }

  scope :active, -> { where(active: true) }
  scope :shopify_stores, -> { where(platform: "shopify") }

  # Required by ShopifyApp::ShopSessionStorage
  # Maps the session storage interface to our database fields
  def self.store(session)
    store = find_or_initialize_by(shopify_domain: session.shop)
    store.shopify_token = session.access_token
    store.access_scopes = session.scope.to_s if session.scope
    store.name = session.shop if store.name.blank?
    store.platform = "shopify"
    store.save!
    store.id
  end

  def self.retrieve(id)
    return unless id

    store = find_by(id: id)
    return unless store

    ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token,
      scope: store.access_scopes
    )
  end

  def self.delete(id)
    store = find_by(id: id)
    store&.destroy
  end

  # Required by ShopifyApp::ShopSessionStorage interface
  def api_version
    "2024-10"
  end

  # Helper methods for the drop-shipping functionality
  def sync_products!
    case platform
    when 'shopify'
      ShopifyProductSyncJob.perform_later(self)
      Rails.logger.info "Shopify product sync job queued for store: #{name} (#{shopify_domain})"
    else
      Rails.logger.warn "Product sync not implemented for platform: #{platform}"
    end
  end

  def process_order!(order_data)
    # Will be implemented in later phases
    Rails.logger.info "Processing order for store: #{name} (#{shopify_domain})"
  end

  def shopify_session
    return unless shopify_token.present?

    ShopifyAPI::Auth::Session.new(
      shop: shopify_domain,
      access_token: shopify_token,
      scope: access_scopes
    )
  end
end
