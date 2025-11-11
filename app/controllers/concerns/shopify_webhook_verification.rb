module ShopifyWebhookVerification
  extend ActiveSupport::Concern

  included do
    skip_before_action :verify_authenticity_token
    before_action :verify_shopify_webhook
  end

  private

  def verify_shopify_webhook
    # Get the HMAC header from Shopify
    hmac_header = request.headers["X-Shopify-Hmac-Sha256"]
    
    unless hmac_header
      Rails.logger.warn "Shopify webhook rejected: Missing HMAC header"
      head :unauthorized
      return false
    end

    # Read the raw request body for HMAC calculation
    # Important: We need to read the body before Rails parses it
    request.body.rewind
    data = request.body.read
    request.body.rewind # Rewind again so controllers can read it

    # Calculate the expected HMAC
    calculated_hmac = calculate_hmac(data)

    # Use secure comparison to prevent timing attacks
    unless ActiveSupport::SecurityUtils.secure_compare(calculated_hmac, hmac_header)
      Rails.logger.warn "Shopify webhook rejected: HMAC verification failed"
      Rails.logger.debug "Expected: #{calculated_hmac}"
      Rails.logger.debug "Received: #{hmac_header}"
      head :unauthorized
      return false
    end

    # Verification successful
    Rails.logger.debug "Shopify webhook HMAC verified successfully"
    true
  end

  def calculate_hmac(data)
    # Use the Shopify API secret to calculate HMAC-SHA256
    secret = ENV["SHOPIFY_API_SECRET"]
    
    if secret.blank?
      Rails.logger.error "SHOPIFY_API_SECRET is not set!"
      raise "SHOPIFY_API_SECRET environment variable is required for webhook verification"
    end

    digest = OpenSSL::Digest.new("sha256")
    Base64.strict_encode64(OpenSSL::HMAC.digest(digest, secret, data))
  end

  def find_store_by_webhook_headers
    shop_domain = request.headers["X-Shopify-Shop-Domain"]
    
    unless shop_domain
      Rails.logger.warn "Shopify webhook: Missing X-Shopify-Shop-Domain header"
      head :bad_request
      return nil
    end

    store = Store.find_by(shopify_domain: shop_domain)
    
    unless store
      Rails.logger.warn "Shopify webhook: Store not found for domain: #{shop_domain}"
      head :not_found
      return nil
    end

    store
  end
end

