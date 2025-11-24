class Connections::Shopify::AuthController < Connections::ApplicationController
  include ShopifyApp::LoginProtection

  def connect
    # Check if Shopify sent us back with a shop parameter (step 2 of OAuth install flow)
    if params[:shop].present?
      # Shopify has redirected back with a shop domain - now initiate OAuth
      remember_post_auth_destination(shop_domain: params[:shop])
      initiate_oauth_for_shop(params[:shop])
    elsif params[:reconnect].present?
      # Reconnection flow - determine if app is still installed or was uninstalled
      shop_domain = params[:reconnect]
      store = Store.find_by(shopify_domain: shop_domain)
      remember_post_auth_destination(store: store, shop_domain: shop_domain)

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
      remember_post_auth_destination
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
    sanitized_shop = shop.to_s.strip
    sanitized_shop = "#{sanitized_shop}.myshopify.com" unless sanitized_shop.include?(".myshopify.com")

    redirect_path = ShopifyApp.configuration.login_callback_url.to_s
    redirect_path = "/#{redirect_path}" unless redirect_path.start_with?("/")
    oauth_attributes = ShopifyAPI::Auth::Oauth.begin_auth(
      shop: sanitized_shop,
      redirect_path: redirect_path,
      is_online: false
    )

    Rails.logger.info "=== Shopify OAuth Install/Refresh ==="
    Rails.logger.info "Shop: #{sanitized_shop}"
    Rails.logger.info "OAuth redirect path: #{redirect_path}"
    Rails.logger.info "Auth route: #{oauth_attributes[:auth_route]}"

    cookies.encrypted[oauth_attributes[:cookie].name] = {
      value: oauth_attributes[:cookie].value,
      expires: oauth_attributes[:cookie].expires,
      secure: true,
      http_only: true
    }

    redirect_to oauth_attributes[:auth_route], allow_other_host: true
  end

  def remember_post_auth_destination(store: nil, shop_domain: nil)
    return if session[:return_to].present?

    inferred_store = store
    if inferred_store.nil? && shop_domain.present?
      inferred_store = current_user&.stores&.find_by(shopify_domain: shop_domain)
    end

    if inferred_store&.uid.present?
      session[:return_to] = connections_store_path(inferred_store.uid)
      return
    elsif request.referer.present?
      referer_uri = URI.parse(request.referer) rescue nil
      session[:return_to] = referer_uri&.path.presence || connections_root_path
      return
    end

    target_shop = shop_domain.presence || params[:shop].presence
    session[:return_to] = if inferred_store&.uid.present?
      connections_store_path(inferred_store.uid)
    elsif target_shop.present?
      connections_root_path(shop: target_shop)
    else
      connections_root_path
    end
  end
end
