require "test_helper"

class Webhooks::ProductsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @previous_secret = ENV["SHOPIFY_API_SECRET"]
    @secret = "test_secret"
    ENV["SHOPIFY_API_SECRET"] = @secret

    @organization = Organization.create!(name: "Webhook Org #{SecureRandom.hex(4)}")
    @user = User.create!(
      email: "products-webhook-#{SecureRandom.hex(4)}@example.com",
      organization: @organization
    )
    @store = Store.create!(
      organization: @organization,
      created_by_user: @user,
      uid: "products-webhook-#{SecureRandom.hex(4)}",
      platform: "shopify",
      shopify_domain: "products-webhook-#{SecureRandom.hex(4)}.myshopify.com",
      name: "Products Webhook Store",
      shopify_token: "test_token",
      access_scopes: "read_products"
    )
  end

  teardown do
    ENV["SHOPIFY_API_SECRET"] = @previous_secret
  end

  test "products delete webhook archives the product and child variants and marks the store for sync" do
    product = Product.create!(
      store: @store,
      external_id: "101",
      title: "Webhook Product",
      handle: "webhook-product",
      status: "active"
    )
    variant = ProductVariant.create!(
      product: product,
      external_variant_id: "201",
      title: "Webhook Variant",
      position: 1,
      price: 42.0
    )

    payload = { id: 101 }.to_json

    post "/webhooks/products/delete",
      params: payload,
      headers: webhook_headers(payload, @store.shopify_domain)

    assert_response :success
    assert product.reload.removed_from_source?
    assert variant.reload.removed_from_source?
    assert_not_nil @store.reload.products_last_updated_at
  end

  private

  def webhook_headers(payload, shop_domain)
    {
      "Content-Type" => "application/json",
      "X-Shopify-Hmac-Sha256" => generate_hmac(payload, @secret),
      "X-Shopify-Shop-Domain" => shop_domain
    }
  end

  def generate_hmac(payload, secret)
    digest = OpenSSL::Digest.new("sha256")
    Base64.strict_encode64(OpenSSL::HMAC.digest(digest, secret, payload))
  end
end
