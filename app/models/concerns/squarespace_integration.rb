module SquarespaceIntegration
  extend ActiveSupport::Concern

  included do
    # Validations specific to Squarespace stores
    validates :squarespace_domain, presence: true, if: :squarespace?
    validates :squarespace_domain, uniqueness: true, allow_blank: true

    # Clear non-Squarespace fields when platform changes
    before_save :clear_non_squarespace_fields
  end

  # Instance methods for Squarespace integration
  def squarespace_api_client
    return nil unless squarespace? && squarespace_token.present?
    
    SquarespaceApiService.new(access_token: squarespace_token, store: self)
  end

  def fetch_site_info!
    return unless squarespace? && squarespace_token.present?
    
    begin
      site_info = squarespace_api_client.get_site_info
      
      # Update store with latest site information
      self.name = site_info["title"] if site_info["title"].present?
      self.squarespace_domain = site_info["siteId"] if site_info["siteId"].present?
      save! if changed?
      
      site_info
    rescue => e
      Rails.logger.error "Failed to fetch Squarespace site info: #{e.message}"
      nil
    end
  end

  def sync_squarespace_products!
    return unless squarespace? && active?

    SquarespaceProductSyncJob.perform_later(self)
    Rails.logger.info "Squarespace product sync job queued for store: #{name} (#{squarespace_domain})"
  end

  # Sync a variant image to Squarespace
  # @param squarespace_variant_id [String] The Squarespace variant ID
  # @param squarespace_product_id [String] The Squarespace product ID
  # @param image_url [String] URL of the image to sync
  # @param alt_text [String, nil] Alt text for the image (optional)
  # @return [Hash] Result with success status and image details
  def sync_squarespace_variant_image(squarespace_variant_id:, squarespace_product_id:, image_url:, alt_text: nil)
    raise ArgumentError, "Not a Squarespace store" unless squarespace?
    raise ArgumentError, "Store must have access token" unless squarespace_token.present?
    
    service = SquarespaceVariantImageSyncService.new(self)
    service.sync_variant_image(
      squarespace_variant_id: squarespace_variant_id,
      squarespace_product_id: squarespace_product_id,
      image_url: image_url,
      alt_text: alt_text
    )
  end

  # Batch sync multiple variant images to Squarespace
  # @param variant_image_data [Array<Hash>] Array of hashes with variant image data
  # @return [Hash] Summary of results
  def batch_sync_squarespace_variant_images(variant_image_data)
    raise ArgumentError, "Not a Squarespace store" unless squarespace?
    raise ArgumentError, "Store must have access token" unless squarespace_token.present?
    
    service = SquarespaceVariantImageSyncService.new(self)
    service.batch_sync_variant_images(variant_image_data)
  end

  def squarespace_admin_url
    return unless squarespace?
    # Squarespace admin URL format is /config for site settings
    "https://#{squarespace_domain}.squarespace.com/config"
  end

  def squarespace_commerce_url
    return unless squarespace?
    "#{squarespace_admin_url}/commerce"
  end

  def squarespace_orders_url
    return unless squarespace?
    "https://#{squarespace_domain}.squarespace.com/commerce/orders"
  end

  def squarespace_site_url
    return unless squarespace?
    # This would be the public-facing site URL
    # For now we use the squarespace.com subdomain
    "https://#{squarespace_domain}.squarespace.com"
  end

  private

  def squarespace?
    platform == "squarespace"
  end

  def clear_non_squarespace_fields
    unless squarespace?
      self.squarespace_domain = nil
      self.squarespace_token = nil
      self.squarespace_refresh_token = nil
      self.squarespace_token_expires_at = nil
      self.squarespace_refresh_token_expires_at = nil
    end
  end

  # Class methods for future Squarespace API integration
  module ClassMethods
    def connect_squarespace_store(domain:, access_token:, store_name: nil)
      store = find_or_initialize_by(squarespace_domain: domain)
      store.squarespace_token = access_token
      store.platform = "squarespace"
      store.name = store_name || domain.split(".").first.humanize
      store.save!
      store
    end
  end
end
