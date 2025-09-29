module WixIntegration
  extend ActiveSupport::Concern

  included do
    # Validations specific to Wix stores
    validates :wix_site_id, presence: true, if: :wix?
    validates :wix_site_id, uniqueness: true, allow_blank: true

    # Clear non-Wix fields when platform changes
    before_save :clear_non_wix_fields
  end

  # Instance methods for Wix integration
  def wix_session
    nil unless wix? && wix_token.present?

    # Future: Return Wix API session/client
    # WixAPI::Session.new(site_id: wix_site_id, access_token: wix_token)
  end

  def sync_wix_products!
    return unless wix?

    # Future implementation
    # WixProductSyncJob.perform_later(self)
    Rails.logger.info "Wix product sync would be queued for store: #{name} (#{wix_site_id})"
  end

  def wix_admin_url
    return unless wix?
    # Future: construct Wix admin URL
    "https://manage.wix.com/dashboard/#{wix_site_id}"
  end

  def wix_products_url
    return unless wix?
    "#{wix_admin_url}/store/products"
  end

  def wix_orders_url
    return unless wix?
    "#{wix_admin_url}/store/orders"
  end

  private

  def wix?
    platform == "wix"
  end

  def clear_non_wix_fields
    unless wix?
      self.wix_site_id = nil
      self.wix_token = nil
    end
  end

  # Class methods for future Wix API integration
  module ClassMethods
    def connect_wix_store(site_id:, access_token:, store_name: nil)
      store = find_or_initialize_by(wix_site_id: site_id)
      store.wix_token = access_token
      store.platform = "wix"
      store.name = store_name || "Wix Store #{site_id}"
      store.save!
      store
    end
  end
end
