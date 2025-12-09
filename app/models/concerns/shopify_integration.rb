module ShopifyIntegration
  extend ActiveSupport::Concern

  # Custom error for inactive stores
  class InactiveStoreError < StandardError; end

  included do
    # Validations specific to Shopify stores
    validates :shopify_domain, presence: true, if: :shopify?
    validates :shopify_domain, uniqueness: true, allow_blank: true
    validates :access_scopes, presence: true, if: :shopify_with_token?

    # Clear non-Shopify fields when platform changes
    before_save :clear_non_platform_fields
  end

  # Instance methods for Shopify integration
  def shopify_session
    return unless shopify? && shopify_token.present?

    # Block API calls to inactive stores
    unless active?
      Rails.logger.warn "Attempted Shopify API call to inactive store: #{name} (#{shopify_domain})"
      raise InactiveStoreError, "Cannot make API calls to inactive store: #{name}"
    end

    ShopifyAPI::Auth::Session.new(
      shop: shopify_domain,
      access_token: shopify_token,
      scope: access_scopes.to_s
    )
  end

  def shopify_api_version
    "2025-10"
  end

  def sync_shopify_products!
    return unless shopify? && active?

    ShopifyProductSyncJob.perform_later(self)
    Rails.logger.info "Shopify product sync job queued for store: #{name} (#{shopify_domain})"
  end

  def sync_variant_image(shopify_variant_id:, image_url:, shopify_product_id: nil, alt_text: nil)
    return unless shopify? && active?

    service = ShopifyVariantImageSyncService.new(self)
    service.sync_variant_image(
      shopify_variant_id: shopify_variant_id,
      image_url: image_url,
      shopify_product_id: shopify_product_id,
      alt_text: alt_text
    )
  end

  def batch_sync_variant_images(variant_image_data)
    return unless shopify? && active?

    service = ShopifyVariantImageSyncService.new(self)
    service.batch_sync_variant_images(variant_image_data)
  end

  def sync_variant_cost(shopify_variant_id:, shopify_product_id:, cost:)
    return unless shopify? && active?

    service = ShopifyVariantCostSyncService.new(self)
    service.sync_variant_cost(
      shopify_variant_id: shopify_variant_id,
      shopify_product_id: shopify_product_id,
      cost: cost
    )
  end

  def update_name_from_shopify!
    return unless shopify? && shopify_token.present? && active?

    begin
      shop_name = self.class.fetch_shop_name_from_api(shopify_session)
      if shop_name.present?
        update!(name: shop_name)
        Rails.logger.info "Updated store name from Shopify API: #{name} (#{shopify_domain})"
      end
    rescue => e
      Rails.logger.error "Failed to update store name from Shopify API: #{e.message}"
    end
  end

  def shopify_admin_url
    return unless shopify?
    "https://#{shopify_domain}/admin"
  end

  def shopify_products_url
    return unless shopify?
    "#{shopify_admin_url}/products"
  end

  def shopify_orders_url
    return unless shopify?
    "#{shopify_admin_url}/orders"
  end

  private

  def shopify?
    platform == "shopify"
  end

  def shopify_with_token?
    shopify? && shopify_token.present?
  end

  def clear_non_platform_fields
    unless shopify?
      self.shopify_domain = nil
      self.shopify_token = nil
      self.access_scopes = nil
    end
  end

  # Class methods
  module ClassMethods
    def fetch_shop_name_from_api(session)
      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

      query = <<~GRAPHQL
        query GetShopName {
          shop {
            id
            name
            myshopifyDomain
          }
        }
      GRAPHQL

      response = client.query(query: query)

      if response.body.dig("data", "shop", "name")
        response.body["data"]["shop"]["name"]
      else
        Rails.logger.error "Failed to fetch shop name: #{response.body['errors'].inspect}"
        nil
      end
    end
  end
end
