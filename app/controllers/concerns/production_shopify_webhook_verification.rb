module ProductionShopifyWebhookVerification
  extend ActiveSupport::Concern

  included do
    skip_before_action :verify_authenticity_token
    before_action :verify_production_shopify_webhook
  end

  private

  def verify_production_shopify_webhook
    shop = (request.headers["X-Shopify-Shop-Domain"] || request.headers["Shopify-Shop-Domain"])
    @production_country = CountryConfig.supported_countries.find do |country|
      domain = CountryConfig.for_country(country)&.dig("shopify_domain")
      domain.present? && domain == shop
    end
    secret = ENV["SHOPIFY_PRODUCTION_WEBHOOK_SECRET_#{@production_country}"] if @production_country
    hmac = (request.headers["X-Shopify-Hmac-Sha256"] || request.headers["Shopify-Hmac-Sha256"])
    unless secret.present? && hmac.present?
      head :unauthorized
      return
    end

    expected = Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret, request.raw_post))
    head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(expected, hmac)
  end
end
