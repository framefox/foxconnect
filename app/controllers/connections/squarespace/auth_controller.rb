class Connections::Squarespace::AuthController < Connections::ApplicationController
  before_action :ensure_development_environment

  def connect
    # Generate CSRF token for OAuth state parameter
    state = SecureRandom.hex(32)
    session[:squarespace_oauth_state] = state

    # Build OAuth authorization URL
    redirect_uri = squarespace_callback_url
    
    # Scopes for full read/write access to products, orders, and inventory
    # Note: Using base scope (e.g. "website.orders") grants both read and write access
    # Using ".read" suffix (e.g. "website.orders.read") grants read-only access
    scopes = [
      "website.orders",
      "website.products",
      "website.inventory"
    ].join(",")

    authorize_url = "https://login.squarespace.com/api/1/login/oauth/provider/authorize?" + {
      client_id: ENV["SQUARESPACE_CLIENT_ID"],
      redirect_uri: redirect_uri,
      scope: scopes,
      state: state,
      access_type: "offline"
    }.to_query

    redirect_to authorize_url, allow_other_host: true
  end

  def callback
    # Verify state parameter to prevent CSRF
    if params[:state] != session[:squarespace_oauth_state]
      flash[:alert] = "Invalid OAuth state parameter. Please try connecting again."
      redirect_to connections_root_path and return
    end

    # Clear the state from session
    session.delete(:squarespace_oauth_state)

    # Handle OAuth errors
    if params[:error].present?
      flash[:alert] = "Squarespace authorization failed: #{params[:error_description] || params[:error]}"
      redirect_to connections_root_path and return
    end

    # Exchange authorization code for access token
    code = params[:code]
    if code.blank?
      flash[:alert] = "No authorization code received from Squarespace."
      redirect_to connections_root_path and return
    end

    begin
      # Use the Squarespace API service to exchange code for token
      api_service = SquarespaceApiService.new
      token_response = api_service.exchange_code_for_token(code, squarespace_callback_url)
      
      access_token = token_response["access_token"]
      
      # Fetch site information
      site_info = api_service.get_site_info(access_token)
      
      # Create or update the store
      store = Store.find_or_initialize_by(squarespace_domain: site_info["siteId"])
      
      store.platform = "squarespace"
      store.squarespace_token = access_token
      store.squarespace_domain = site_info["siteId"]
      store.name = site_info["title"] || site_info["siteId"]
      store.organization ||= current_user.organization
      store.created_by_user ||= current_user
      
      # Store token expiration times (Squarespace returns Unix timestamps)
      if token_response["access_token_expires_at"].present?
        store.squarespace_token_expires_at = Time.at(token_response["access_token_expires_at"].to_f)
      end
      
      # Store refresh token if provided (only when access_type=offline)
      if token_response["refresh_token"].present?
        store.squarespace_refresh_token = token_response["refresh_token"]
        
        if token_response["refresh_token_expires_at"].present?
          store.squarespace_refresh_token_expires_at = Time.at(token_response["refresh_token_expires_at"].to_f)
        end
      end
      
      if store.save
        Rails.logger.info "Squarespace store connected: #{store.name}"
        Rails.logger.info "Access token expires at: #{store.squarespace_token_expires_at}"
        Rails.logger.info "Refresh token present: #{store.squarespace_refresh_token.present?}"
        
        flash[:notice] = "Successfully connected #{store.name}!"
        redirect_to connections_store_path(store)
      else
        flash[:alert] = "Failed to save store: #{store.errors.full_messages.join(", ")}"
        redirect_to connections_root_path
      end

    rescue => e
      Rails.logger.error "Squarespace OAuth callback error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      flash[:alert] = "Failed to connect Squarespace store: #{e.message}"
      redirect_to connections_root_path
    end
  end

  def disconnect
    store = current_user.stores.find_by(uid: params[:uid])
    if store && store.squarespace?
      store.destroy
      flash[:notice] = "Successfully disconnected #{store.name} from Framefox Connect."
    else
      flash[:alert] = "Store not found."
    end

    redirect_to connections_root_path
  end

  private

  def ensure_development_environment
    unless Rails.env.development?
      flash[:alert] = "Squarespace integration is not yet available in production."
      redirect_to connections_root_path
    end
  end

  def squarespace_callback_url
    # Use the current request's protocol and host to build the callback URL
    # This handles both localhost:3000 and connect.framefox.com
    "#{request.protocol}#{request.host_with_port}/connections/squarespace/callback"
  end
end

