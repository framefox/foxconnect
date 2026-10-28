require "test_helper"

class ShopifyLaunchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    organization = Organization.create!(name: "Shopify launch test")
    @user = User.create!(email: "shopify-launch@example.com", password: "launch-test-password", organization: organization)
    @shop = "launch-test.myshopify.com"
  end

  test "Shopify installation return reaches the connection flow instead of losing the shop" do
    sign_in @user, scope: :user
    get root_path, params: { shop: @shop, hmac: "launch-signature", timestamp: Time.current.to_i }
    assert_redirected_to connections_shopify_connect_path(shop: @shop)
  end

  test "signed out Shopify launch resumes the connection after signing in" do
    get root_path, params: { shop: @shop }
    assert_redirected_to connections_shopify_connect_path(shop: @shop)
    follow_redirect!
    assert_redirected_to new_user_session_path

    post user_session_path, params: { user: { email: @user.email, password: "launch-test-password" } }
    assert_redirected_to connections_shopify_connect_path(shop: @shop)
  end

  test "ordinary homepage visits retain their dashboard redirect" do
    sign_in @user, scope: :user
    get root_path
    assert_redirected_to home_path
  end

  test "untrusted shop domains cannot initiate a Shopify launch" do
    get root_path, params: { shop: "attacker.example" }
    assert_response :bad_request
  end
end
