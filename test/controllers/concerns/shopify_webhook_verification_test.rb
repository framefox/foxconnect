require "test_helper"

class ShopifyWebhookVerificationTest < ActionDispatch::IntegrationTest
  setup do
    @previous_secret = ENV["SHOPIFY_API_SECRET"]
    @secret = "test_secret"
    ENV["SHOPIFY_API_SECRET"] = @secret
    @shop_domain = "test-shop.myshopify.com"
    @webhook_data = { id: 12345, test: "data" }.to_json
    @valid_hmac = generate_hmac(@webhook_data, @secret)
    @organization = Organization.create!(name: "Test Org")
    @user = User.create!(
      email: "webhook-test@example.com",
      organization: @organization
    )
  end

  teardown do
    ENV["SHOPIFY_API_SECRET"] = @previous_secret
  end

  test "webhook with valid HMAC should be accepted" do
    create_store!

    # Make request with valid HMAC
    post webhooks_app_uninstalled_path,
      params: @webhook_data,
      headers: {
        "Content-Type" => "application/json",
        "X-Shopify-Hmac-Sha256" => @valid_hmac,
        "X-Shopify-Shop-Domain" => @shop_domain
      }

    assert_response :success
  end

  test "webhook with invalid HMAC should be rejected" do
    create_store!

    # Make request with invalid HMAC
    post webhooks_app_uninstalled_path,
      params: @webhook_data,
      headers: {
        "Content-Type" => "application/json",
        "X-Shopify-Hmac-Sha256" => "invalid_hmac",
        "X-Shopify-Shop-Domain" => @shop_domain
      }

    assert_response :unauthorized
  end

  test "webhook without HMAC header should be rejected" do
    # Make request without HMAC header
    post webhooks_app_uninstalled_path,
      params: @webhook_data,
      headers: {
        "Content-Type" => "application/json",
        "X-Shopify-Shop-Domain" => @shop_domain
      }

    assert_response :unauthorized
  end

  test "webhook without shop domain header should be rejected" do
    # Make request without shop domain header
    post webhooks_orders_create_path,
      params: @webhook_data,
      headers: {
        "Content-Type" => "application/json",
        "X-Shopify-Hmac-Sha256" => @valid_hmac
      }

    assert_response :bad_request
  end

  test "webhook with non-existent store should be rejected" do
    # Make request for non-existent store
    post webhooks_orders_create_path,
      params: @webhook_data,
      headers: {
        "Content-Type" => "application/json",
        "X-Shopify-Hmac-Sha256" => @valid_hmac,
        "X-Shopify-Shop-Domain" => "non-existent-store.myshopify.com"
      }

    assert_response :not_found
  end

  test "GDPR webhooks should verify HMAC correctly" do
    create_store!

    # Test customers/data_request webhook
    gdpr_data = { shop_domain: @shop_domain, customer: { id: 12345 } }.to_json
    valid_gdpr_hmac = generate_hmac(gdpr_data, @secret)

    post webhooks_customers_data_request_path,
      params: gdpr_data,
      headers: {
        "Content-Type" => "application/json",
        "X-Shopify-Hmac-Sha256" => valid_gdpr_hmac,
        "X-Shopify-Shop-Domain" => @shop_domain
      }

    assert_response :success
  end

  private

  def generate_hmac(data, secret)
    digest = OpenSSL::Digest.new("sha256")
    Base64.strict_encode64(OpenSSL::HMAC.digest(digest, secret, data))
  end

  def create_store!
    Store.create!(
      organization: @organization,
      created_by_user: @user,
      uid: "webhook-test-store",
      platform: "shopify",
      shopify_domain: @shop_domain,
      name: "Test Store",
      shopify_token: "test_token",
      access_scopes: "read_products"
    )
  end
end
