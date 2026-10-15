require "test_helper"
require "minitest/mock"

class Webhooks::ShopifyReliabilityTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  setup do
    @old_secret = ENV["SHOPIFY_API_SECRET"]
    ENV["SHOPIFY_API_SECRET"] = "merchant-secret"
    org = Organization.create!(name: "Webhook Reliability")
    user = User.create!(email: "reliability-#{SecureRandom.hex(4)}@example.com", organization: org)
    @store = Store.create!(organization: org, created_by_user: user, name: "Webhook Store", platform: "shopify",
      shopify_domain: "reliability-#{SecureRandom.hex(4)}.myshopify.com", shopify_token: "token", access_scopes: "read_orders")
    clear_enqueued_jobs
  end

  teardown do
    ENV["SHOPIFY_API_SECRET"] = @old_secret
  end

  test "failed delivery is processed again while a successful duplicate is skipped" do
    payload = { id: 1 }.to_json
    id = SecureRandom.uuid
    log = WebhookLog.create!(topic: "products/create", webhook_id: id, status_code: 500, payload: payload)
    post "/webhooks/products/create", params: payload, headers: headers_for(payload, id)
    assert_response :success
    assert_equal 200, log.reload.status_code
    timestamp = @store.reload.products_last_updated_at
    travel 2.seconds do
      post "/webhooks/products/create", params: payload, headers: headers_for(payload, id)
      assert_response :success
      assert_equal timestamp, @store.reload.products_last_updated_at
    end
  end

  test "order delivery enqueues one durable job and duplicates do not requeue" do
    payload = { id: 12 }.to_json
    id = SecureRandom.uuid
    assert_enqueued_jobs 1, only: ShopifyOrderImportJob do
      post "/webhooks/orders/create", params: payload, headers: headers_for(payload, id)
      assert_response :accepted
      post "/webhooks/orders/create", params: payload, headers: headers_for(payload, id)
      assert_response :success
    end
    assert_equal 202, WebhookLog.find_by!(webhook_id: id).status_code
  end

  test "topic-based fulfillment payload without kind is queued" do
    payload = { submitted_fulfillment_order: { id: "gid://shopify/FulfillmentOrder/1" } }.to_json
    topic = "fulfillment_orders/fulfillment_request_submitted"
    assert_enqueued_with(job: ShopifyFulfillmentRequestJob) do
      post "/webhooks/#{topic}", params: payload, headers: headers_for(payload, SecureRandom.uuid).merge("X-Shopify-Topic" => topic)
      assert_response :accepted
    end
  end

  test "callback cancellation payload is queued" do
    payload = { kind: "CANCELLATION_REQUEST" }.to_json
    assert_enqueued_with(job: ShopifyFulfillmentRequestJob) do
      post "/webhooks/fulfillment_order_notification", params: payload, headers: headers_for(payload, SecureRandom.uuid)
      assert_response :accepted
    end
  end

  test "production endpoints reject unsigned requests" do
    %w[/webhooks/orders/paid /webhooks/fulfillments/create /webhooks/fulfillments/update].each do |path|
      post path, params: { id: 1 }.to_json, headers: { "Content-Type" => "application/json" }
      assert_response :unauthorized
    end
  end

  test "production webhook must match both configured shop and its own signing secret" do
    old = ENV["SHOPIFY_PRODUCTION_WEBHOOK_SECRET_NZ"]
    ENV["SHOPIFY_PRODUCTION_WEBHOOK_SECRET_NZ"] = "production-secret"
    payload = { id: "nonexistent" }.to_json
    config = ->(country) { { "shopify_domain" => "#{country.downcase}-production.myshopify.com" } }
    CountryConfig.stub(:for_country, config) do
      headers = headers_for(payload, SecureRandom.uuid).merge("X-Shopify-Shop-Domain" => "nz-production.myshopify.com")
      post "/webhooks/orders/paid", params: payload, headers: headers
      assert_response :unauthorized
      headers["X-Shopify-Hmac-Sha256"] = hmac(payload, "production-secret")
      post "/webhooks/orders/paid", params: payload, headers: headers
      assert_response :success
    end
  ensure
    ENV["SHOPIFY_PRODUCTION_WEBHOOK_SECRET_NZ"] = old
  end

  test "job retries failed processing and successful re-execution is idempotent" do
    log = WebhookLog.create!(topic: "orders/create", status_code: 202, payload: {})
    job = ShopifyWebhookJob.new
    assert_raises(RuntimeError) { job.send(:process_delivery, log.id) { raise "Temporary failure" } }
    assert_equal 500, log.reload.status_code
    assert_nil log.processed_at
    calls = 0
    2.times { job.send(:process_delivery, log.id) { calls += 1 } }
    assert_equal 1, calls
    assert log.reload.processed_at
    assert_equal 200, log.status_code
  end

  test "recovery requeues stalled delivery once and leaves completed work alone" do
    pending = WebhookLog.create!(topic: "orders/create", shop_domain: @store.shopify_domain,
      status_code: 202, payload: { id: 123 }, updated_at: 20.minutes.ago)
    WebhookLog.create!(topic: "orders/create", shop_domain: @store.shopify_domain,
      status_code: 200, processed_at: Time.current, payload: { id: 456 }, updated_at: 20.minutes.ago)
    assert_enqueued_jobs 1, only: ShopifyOrderImportJob do
      RecoverShopifyWebhooksJob.perform_now
      RecoverShopifyWebhooksJob.perform_now
    end
    assert pending.reload.updated_at > 1.minute.ago
  end

  test "current Shopify headers are verified and queued" do
    payload = { id: 123 }.to_json
    headers = headers_for(payload, SecureRandom.uuid).transform_keys { |key| key.delete_prefix("X-") }
    assert_enqueued_jobs 1, only: ShopifyOrderImportJob do
      post "/webhooks/orders/create", params: payload, headers: headers
      assert_response :accepted
    end
  end

  private

  def headers_for(payload, id)
    { "Content-Type" => "application/json", "X-Shopify-Shop-Domain" => @store.shopify_domain,
      "X-Shopify-Webhook-Id" => id, "X-Shopify-Hmac-Sha256" => hmac(payload, "merchant-secret") }
  end

  def hmac(payload, secret)
    Base64.strict_encode64(OpenSSL::HMAC.digest("SHA256", secret, payload))
  end
end
