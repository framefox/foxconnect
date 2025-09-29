module ShopifySessionStorage
  extend ActiveSupport::Concern

  included do
    include ShopifyApp::ShopSessionStorage
  end

  # Class methods required by ShopifyApp::ShopSessionStorage interface
  module ClassMethods
    # Note: The store method is now defined directly in the Store model to override ShopifyApp's implementation

    def retrieve(id)
      return unless id

      store = find_by(id: id)
      return unless store

      ShopifyAPI::Auth::Session.new(
        shop: store.shopify_domain,
        access_token: store.shopify_token,
        scope: store.access_scopes.to_s
      )
    end

    def delete(id)
      store = find_by(id: id)
      store&.destroy
    end
  end

  # Required by ShopifyApp::ShopSessionStorage interface
  def api_version
    shopify_api_version
  end
end
