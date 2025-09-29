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
  def squarespace_session
    nil unless squarespace? && squarespace_token.present?

    # Future: Return Squarespace API session/client
    # SquarespaceAPI::Session.new(domain: squarespace_domain, access_token: squarespace_token)
  end

  def sync_squarespace_products!
    return unless squarespace?

    # Future implementation
    # SquarespaceProductSyncJob.perform_later(self)
    Rails.logger.info "Squarespace product sync would be queued for store: #{name} (#{squarespace_domain})"
  end

  def squarespace_admin_url
    return unless squarespace?
    "https://#{squarespace_domain}/config"
  end

  def squarespace_commerce_url
    return unless squarespace?
    "#{squarespace_admin_url}/commerce"
  end

  def squarespace_orders_url
    return unless squarespace?
    "#{squarespace_commerce_url}/orders"
  end

  def squarespace_site_url
    return unless squarespace?
    "https://#{squarespace_domain}"
  end

  private

  def squarespace?
    platform == "squarespace"
  end

  def clear_non_squarespace_fields
    unless squarespace?
      self.squarespace_domain = nil
      self.squarespace_token = nil
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
