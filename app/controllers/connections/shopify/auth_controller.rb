class Connections::Shopify::AuthController < Connections::ApplicationController
  include ShopifyApp::LoginProtection

  def connect
    # Check if Shopify sent us back with a shop parameter (step 2 of OAuth install flow)
    if params[:shop].present?
      # Shopify has redirected back with a shop domain - now initiate OAuth
      initiate_oauth_for_shop(params[:shop])
    elsif params[:reconnect].present?
      # Reconnection flow - determine if app is still installed or was uninstalled
      shop_domain = params[:reconnect]
      store = Store.find_by(shopify_domain: shop_domain)
      
      if store&.shopify_token.blank?
        # App was uninstalled (token was cleared by webhook) - need full OAuth install flow
        oauth_url = "https://admin.shopify.com/oauth/install?client_id=#{ENV['SHOPIFY_API_KEY']}&shop=#{shop_domain}"
        
        Rails.logger.info "=== Shopify OAuth Reconnect (App Uninstalled) ==="
        Rails.logger.info "Shop: #{shop_domain}"
        Rails.logger.info "Token is blank - app was uninstalled, using full install flow"
        Rails.logger.info "Redirecting to: #{oauth_url}"
        
        redirect_to oauth_url, allow_other_host: true
      else
        # App still installed - token just invalid/expired, go directly to OAuth authorize
        Rails.logger.info "=== Shopify OAuth Reconnect (Token Refresh) ==="
        Rails.logger.info "Shop: #{shop_domain}"
        Rails.logger.info "Token exists - app still installed, refreshing token via OAuth authorize"
        
        initiate_oauth_for_shop(shop_domain)
      end
    else
      # Step 1: Redirect to Shopify's OAuth install URL (user will pick store)
      # This complies with Shopify's requirement that apps must not request manual entry of myshopify.com URLs
      oauth_url = "https://admin.shopify.com/oauth/install?client_id=#{ENV['SHOPIFY_API_KEY']}"

      Rails.logger.info "=== Shopify OAuth Install - Step 1 ==="
      Rails.logger.info "Redirecting to: #{oauth_url}"

      redirect_to oauth_url, allow_other_host: true
    end
  end

  def callback
    # This is handled by the ShopifyApp engine
    # After successful auth, user will be redirected to root_url (/connections)
    # The connections dashboard controller will check for newly created stores
    # and redirect to the store show page with welcome modal if needed
    redirect_to connections_root_path
  end

  def disconnect
    store = current_user.stores.find_by(uid: params[:uid])
    if store
      store.destroy
      flash[:notice] = "Successfully disconnected #{store.name} from Framefox Connect."
    else
      flash[:alert] = "Store not found."
    end

    redirect_to connections_root_path
  end

  private

  def initiate_oauth_for_shop(shop)
    # Sanitize shop domain
    shop = shop.to_s.strip
    shop = "#{shop}.myshopify.com" unless shop.include?(".myshopify.com")

    callback_url = "#{request.base_url}/connections/auth/shopify/callback"
    scopes = ShopifyApp.configuration.scope

    # Generate state token for CSRF protection
    state = SecureRandom.hex(32)
    session[:shopify_oauth_state] = state

    oauth_params = {
      client_id: ENV["SHOPIFY_API_KEY"],
      scope: scopes,
      redirect_uri: callback_url,
      state: state
    }

    oauth_url = "https://#{shop}/admin/oauth/authorize?#{oauth_params.to_query}"

    Rails.logger.info "=== Shopify OAuth Install - Step 2 ==="
    Rails.logger.info "Shop: #{shop}"
    Rails.logger.info "Callback URL: #{callback_url}"
    Rails.logger.info "Scopes: #{scopes}"
    Rails.logger.info "State: #{state}"
    Rails.logger.info "OAuth URL: #{oauth_url}"

    redirect_to oauth_url, allow_other_host: true
  end
end
