class SquarespaceApiService
  BASE_URL = "https://api.squarespace.com"
  TOKEN_URL = "https://login.squarespace.com/api/1/login/oauth/provider/tokens"

  def initialize(access_token: nil)
    @access_token = access_token
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
    raise ArgumentError, "Access token is required" if @access_token.blank?

    response = HTTP.headers(authorization_headers)
      .post("#{BASE_URL}/1.0/commerce/orders/#{order_id}/fulfillments",
        json: fulfillment_data)

    handle_response(response, "Failed to fulfill order")
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

  def handle_response(response, error_message)
    case response.code
    when 200..299
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
