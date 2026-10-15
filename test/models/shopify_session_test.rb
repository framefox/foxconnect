require "test_helper"
require "minitest/mock"

class ShopifySessionTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @organization = Organization.create!(name: "Token Test")
    @user = User.create!(email: "tokens-#{SecureRandom.hex(4)}@example.com", organization: @organization)
    @shop = "tokens-#{SecureRandom.hex(4)}.myshopify.com"
  end

  test "OAuth persists granted scopes and encrypted refresh credentials" do
    session = token_session
    id = Store.store(session, user: @user)
    store = Store.find(id)
    assert_equal "read_products", store.access_scopes
    assert_in_delta session.expires.to_f, store.expires_at.to_f, 1
    assert_equal "refresh-secret", store.refresh_token
    refute_includes store.read_attribute_before_type_cast(:refresh_token), '"refresh-secret"'
    assert_equal "refresh-secret", Store.retrieve(id).refresh_token
  end

  test "expired access token refreshes once and subsequent reads use the rotated credentials" do
    store = Store.find(Store.store(token_session, user: @user))
    store.update!(expires_at: 1.minute.ago)
    fresh = token_session(access_token: "rotated-access", refresh_token: "rotated-refresh")
    calls = 0
    ShopifyAPI::Auth::RefreshToken.stub(:refresh_access_token, ->(**args) {
      calls += 1
      assert_equal "refresh-secret", args[:refresh_token]
      fresh
    }) do
      assert_equal "rotated-access", store.shopify_session.access_token
      assert_equal "rotated-access", Store.retrieve(store.id).access_token
    end
    assert_equal 1, calls
    assert_equal "rotated-refresh", store.reload.refresh_token
  end

  test "expired refresh token fails closed" do
    store = Store.find(Store.store(token_session, user: @user))
    store.update!(expires_at: 1.minute.ago, refresh_token_expires_at: 1.minute.ago)
    assert_raises(ShopifyApp::RefreshTokenExpiredError) { store.shopify_session }
  end

  test "legacy tokens remain usable until explicitly migrated" do
    store = Store.find(Store.store(ShopifyAPI::Auth::Session.new(shop: @shop, access_token: "legacy", scope: "read_products"), user: @user))
    assert_equal "legacy", store.shopify_session.access_token
  end

  private

  def token_session(access_token: "access", refresh_token: "refresh-secret")
    ShopifyAPI::Auth::Session.new(shop: @shop, access_token: access_token, scope: "read_products",
      expires: 1.hour.from_now.to_time, refresh_token: refresh_token,
      refresh_token_expires: 90.days.from_now.to_time)
  end
end
