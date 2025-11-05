class SquarespaceApiService
  BASE_URL = "https://api.squarespace.com"
  TOKEN_URL = "https://login.squarespace.com/api/1/login/oauth/provider/tokens"

  def initialize(access_token: nil, store: nil)
    @access_token = access_token
    @store = store
  end

  # Exchange authorization code for access token
  def exchange_code_for_token(code, redirect_uri)
    # Squarespace uses Basic Authentication for token exchange
    # Encode client_id:client_secret in Base64
    credentials = Base64.strict_encode64("#{ENV['SQUARESPACE_CLIENT_ID']}:#{ENV['SQUARESPACE_SECRET']}")

    response = HTTP.headers(
      "Content-Type" => "application/json",
      "Authorization" => "Basic #{credentials}",
      "User-Agent" => "Framefox Connect / 1.0"
    ).post(TOKEN_URL, json: {
      grant_type: "authorization_code",
      code: code,
      redirect_uri: redirect_uri
    })

    handle_response(response, "Failed to exchange authorization code for token")
  end

  # Get basic site information
  def get_site_info(access_token = nil)
    token = access_token || @access_token
    raise ArgumentError, "Access token is required" if token.blank?

    response = HTTP.headers(authorization_headers(token))
      .get("#{BASE_URL}/1.0/authorization/website")

    handle_response(response, "Failed to fetch site information")
  end

  # Get all products for a site using v2 API
  def get_products(cursor: nil)
    raise ArgumentError, "Access token is required" if @access_token.blank?

    url = "#{BASE_URL}/v2/commerce/products"
    url += "?cursor=#{cursor}" if cursor.present?

    response = HTTP.headers(authorization_headers).get(url)
    handle_response(response, "Failed to fetch products")
  end

  # Get a specific product by ID using v2 API
  def get_product(product_id)
    raise ArgumentError, "Access token is required" if @access_token.blank?

    response = HTTP.headers(authorization_headers)
      .get("#{BASE_URL}/v2/commerce/products/#{product_id}")

    handle_response(response, "Failed to fetch product")
  end

  # Get all orders
  def get_orders(modified_after: nil, modified_before: nil, cursor: nil)
    raise ArgumentError, "Access token is required" if @access_token.blank?

    params = {}
    params[:modifiedAfter] = modified_after if modified_after
    params[:modifiedBefore] = modified_before if modified_before
    params[:cursor] = cursor if cursor

    url = "#{BASE_URL}/1.0/commerce/orders"
    url += "?#{params.to_query}" if params.any?

    response = HTTP.headers(authorization_headers).get(url)
    handle_response(response, "Failed to fetch orders")
  end

  # Get a specific order by ID
  def get_order(order_id)
    raise ArgumentError, "Access token is required" if @access_token.blank?

    response = HTTP.headers(authorization_headers)
      .get("#{BASE_URL}/1.0/commerce/orders/#{order_id}")

    handle_response(response, "Failed to fetch order")
  end

  # Create a fulfillment for an order
  def fulfill_order(order_id, fulfillment_data)
    ensure_valid_token!

    response = HTTP.headers(authorization_headers)
      .post("#{BASE_URL}/1.0/commerce/orders/#{order_id}/fulfillments",
        json: fulfillment_data)

    handle_response(response, "Failed to fulfill order")
  end

  # Refresh the access token using a refresh token
  # @param refresh_token [String] The refresh token
  # @return [Hash] Response with new access_token, refresh_token, and expiration times
  def refresh_access_token(refresh_token)
    raise ArgumentError, "Refresh token is required" if refresh_token.blank?

    credentials = Base64.strict_encode64("#{ENV['SQUARESPACE_CLIENT_ID']}:#{ENV['SQUARESPACE_SECRET']}")

    response = HTTP.headers(
      "Content-Type" => "application/json",
      "Authorization" => "Basic #{credentials}",
      "User-Agent" => "Framefox Connect / 1.0"
    ).post(TOKEN_URL, json: {
      grant_type: "refresh_token",
      refresh_token: refresh_token
    })

    handle_response(response, "Failed to refresh access token")
  end

  # Upload an image to a product using v2 API
  # @param product_id [String] The Squarespace product ID
  # @param image_url [String] URL of the image to download and upload
  # @param filename [String] Filename for the uploaded image (used for alt text and URL)
  # @return [Hash] Response with imageId
  def upload_product_image(product_id, image_url, filename)
    ensure_valid_token!
    raise ArgumentError, "Product ID is required" if product_id.blank?
    raise ArgumentError, "Image URL is required" if image_url.blank?

    Rails.logger.info "Downloading image from #{image_url}"

    # Download the image from the URL
    image_response = HTTP.follow.get(image_url)

    unless image_response.status.success?
      raise SquarespaceApiError, "Failed to download image from #{image_url}: #{image_response.status}"
    end

    image_data = image_response.body.to_s

    Rails.logger.info "Uploading image to Squarespace product #{product_id} with filename: #{filename}"

    # Upload using multipart/form-data
    # Squarespace requires name="file" and filename to be set
    response = HTTP.headers(
      "Authorization" => "Bearer #{@access_token}",
      "User-Agent" => "Framefox Connect / 1.0"
    ).post(
      "#{BASE_URL}/v2/commerce/products/#{product_id}/images",
      form: {
        file: HTTP::FormData::File.new(StringIO.new(image_data),
          content_type: "image/jpeg",
          filename: filename)
      }
    )

    handle_response(response, "Failed to upload product image")
  end

  # Check the upload status of a product image
  # @param product_id [String] The Squarespace product ID
  # @param image_id [String] The image ID returned from upload
  # @return [Hash] Response with status: PROCESSING | READY | ERROR
  def get_image_status(product_id, image_id)
    ensure_valid_token!
    raise ArgumentError, "Product ID is required" if product_id.blank?
    raise ArgumentError, "Image ID is required" if image_id.blank?

    response = HTTP.headers(authorization_headers)
      .get("#{BASE_URL}/v2/commerce/products/#{product_id}/images/#{image_id}/status")

    handle_response(response, "Failed to get image status")
  end

  # Assign an image to a specific variant
  # @param product_id [String] The Squarespace product ID
  # @param variant_id [String] The Squarespace variant ID
  # @param image_id [String] The image ID to assign
  # @return [Hash] Response from the API
  def assign_image_to_variant(product_id, variant_id, image_id)
    ensure_valid_token!
    raise ArgumentError, "Product ID is required" if product_id.blank?
    raise ArgumentError, "Variant ID is required" if variant_id.blank?
    raise ArgumentError, "Image ID is required" if image_id.blank?

    Rails.logger.info "Assigning image #{image_id} to variant #{variant_id} on product #{product_id}"

    # v2 API supports image assignment for all product types with variants
    # Note: endpoint is /image (singular), not /images (plural)
    url = "#{BASE_URL}/v2/commerce/products/#{product_id}/variants/#{variant_id}/image"
    Rails.logger.info "Request URL: #{url}"
    Rails.logger.info "Request body: { imageId: #{image_id} }"

    response = HTTP.headers(authorization_headers)
      .post(url, json: { imageId: image_id })

    Rails.logger.info "Response status: #{response.code}"
    Rails.logger.info "Response body: #{response.body.to_s[0..500]}"

    # Successful response returns 204 NO CONTENT (no body)
    if response.code == 204
      { success: true }
    else
      handle_response(response, "Failed to assign image to variant")
    end
  end

  private

  def default_headers
    {
      "Content-Type" => "application/json",
      "User-Agent" => "Framefox Connect / 1.0"
    }
  end

  def authorization_headers(token = nil)
    token = token || @access_token
    default_headers.merge({
      "Authorization" => "Bearer #{token}"
    })
  end

  # Ensures we have a valid access token, refreshing if necessary
  # Follows Squarespace best practice: check if expires_at - currentTime > 10 seconds
  def ensure_valid_token!
    raise ArgumentError, "Access token is required" if @access_token.blank?

    # If we don't have a store, we can't refresh the token automatically
    return unless @store

    # Check if token is expired or will expire in the next 10 seconds
    if @store.squarespace_token_expires_at.present?
      time_until_expiry = @store.squarespace_token_expires_at - Time.current

      if time_until_expiry <= 10.seconds
        Rails.logger.info "Squarespace access token expired or expiring soon, refreshing..."
        refresh_store_token!
      end
    end
  end

  # Refreshes the store's access token using the refresh token
  def refresh_store_token!
    return unless @store&.squarespace_refresh_token.present?

    begin
      token_response = refresh_access_token(@store.squarespace_refresh_token)

      # Update the store with new tokens
      # Note: Squarespace returns new refresh tokens with each refresh (they're one-time use)
      @store.squarespace_token = token_response["access_token"]
      @store.squarespace_token_expires_at = Time.at(token_response["access_token_expires_at"].to_f)

      if token_response["refresh_token"].present?
        @store.squarespace_refresh_token = token_response["refresh_token"]
        @store.squarespace_refresh_token_expires_at = Time.at(token_response["refresh_token_expires_at"].to_f)
      end

      @store.save!

      # Update the instance variable with the new token
      @access_token = token_response["access_token"]

      Rails.logger.info "Successfully refreshed Squarespace access token for store: #{@store.name}"
    rescue => e
      Rails.logger.error "Failed to refresh Squarespace token: #{e.message}"
      raise SquarespaceAuthError, "Token refresh failed: #{e.message}"
    end
  end

  def handle_response(response, error_message)
    case response.code
    when 200..299
      # Handle 204 NO CONTENT (no body to parse)
      return { success: true } if response.code == 204 || response.body.to_s.strip.empty?
      JSON.parse(response.body.to_s)
    when 401
      raise SquarespaceAuthError, "Authentication failed: #{response.body}"
    when 429
      raise SquarespaceRateLimitError, "Rate limit exceeded: #{response.body}"
    else
      error_body = JSON.parse(response.body.to_s) rescue response.body.to_s
      error_detail = error_body.is_a?(Hash) ? error_body["message"] : error_body
      raise SquarespaceApiError, "#{error_message}: #{response.code} - #{error_detail}"
    end
  end

  # Custom error classes
  class SquarespaceApiError < StandardError; end
  class SquarespaceAuthError < SquarespaceApiError; end
  class SquarespaceRateLimitError < SquarespaceApiError; end
end
