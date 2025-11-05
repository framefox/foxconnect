module ShopifySessionStorage
  extend ActiveSupport::Concern

  included do
    include ShopifyApp::ShopSessionStorage
    
    # Temporarily set dummy values for Shopify fields during validation if not a Shopify store
    # This prevents ShopifyApp's unconditional validations from failing
    before_validation :set_dummy_shopify_fields_for_non_shopify_stores
    after_validation :clear_dummy_shopify_fields_for_non_shopify_stores
  end
  
  private
  
  def set_dummy_shopify_fields_for_non_shopify_stores
    unless shopify?
      @_original_shopify_domain = shopify_domain
      @_original_shopify_token = shopify_token
      
      # Set temporary dummy values to pass ShopifyApp's validations
      self.shopify_domain = "dummy.myshopify.com" if shopify_domain.blank?
      self.shopify_token = "dummy_token" if shopify_token.blank?
    end
  end
  
  def clear_dummy_shopify_fields_for_non_shopify_stores
    unless shopify?
      # Restore original (nil) values
      self.shopify_domain = @_original_shopify_domain
      self.shopify_token = @_original_shopify_token
    end
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
