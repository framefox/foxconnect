require "test_helper"
require "minitest/mock"

class ShopifyWebhookDeliveryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    org = Organization.create!(name: "Delivery tests")
    @user = User.create!(email: "delivery-#{SecureRandom.hex(5)}@example.com", organization: org)
    @store = Store.create!(organization: org, created_by_user: @user, name: "Delivery store", platform: "shopify",
      shopify_domain: "delivery-#{SecureRandom.hex(5)}.myshopify.com", shopify_token: "token", access_scopes: "read_orders")
    @log = WebhookLog.create!(topic: "orders/create", store: @store, shop_domain: @store.shopify_domain,
      payload: { id: 123 }, status_code: 202, updated_at: 20.minutes.ago)
    clear_enqueued_jobs
  end

  test "recovery does not add attempts while a delivery is queued" do
    assert_enqueued_jobs 1, only: ShopifyOrderImportJob do
      Shopify::WebhookDelivery.enqueue(@log)
      travel 11.minutes do
        3.times { RecoverShopifyWebhooksJob.perform_now }
      end
    end
    assert_equal "queued", @log.reload.delivery_state
    assert_equal "123", @log.delivery_subject_id
  end

  test "queue backlog never gets replaced just because the lease expires" do
    Shopify::WebhookDelivery.enqueue(@log)
    owner = @log.reload.delivery_job_id
    recovery = RecoverShopifyWebhooksJob.new
    travel 2.days do
      recovery.stub(:queued_job_ids, Set[owner]) do
        assert_no_enqueued_jobs(only: ShopifyOrderImportJob) { recovery.perform }
      end
    end
    assert_equal owner, @log.reload.delivery_job_id
  end

  test "recovery skips a running delivery even after its lease expires" do
    ready = Queue.new
    release = Queue.new
    # Rails transactional tests share a pinned connection between threads.
    # Use a separate PG session to exercise the actual cross-worker lock.
    config = ActiveRecord::Base.connection.raw_connection.conninfo_hash
    thread = Thread.new do
      connection = PG.connect(config.slice(:host, :port, :dbname, :user, :password))
      connection.exec_params("SELECT pg_advisory_lock(74001,$1::integer)", [ @log.id ])
      ready << true
      release.pop
    ensure
      connection&.close
    end
    ready.pop
    assert_no_enqueued_jobs(only: ShopifyOrderImportJob) { RecoverShopifyWebhooksJob.perform_now }
  ensure
    release << true
    thread&.join
  end

  test "expired enqueue lease replaces ownership and old queued jobs cannot execute" do
    Shopify::WebhookDelivery.enqueue(@log)
    old_id = @log.reload.delivery_job_id
    travel 31.minutes do
      assert_enqueued_jobs 1, only: ShopifyOrderImportJob do
        RecoverShopifyWebhooksJob.perform_now
      end
      refute_equal old_id, @log.reload.delivery_job_id
      old_job = ShopifyWebhookJob.new
      old_job.job_id = old_id
      old_job.send(:process_delivery, @log.id) { flunk "Obsolete job executed" }
      current_job = ShopifyWebhookJob.new
      current_job.job_id = @log.delivery_job_id
      calls = 0
      2.times { current_job.send(:process_delivery, @log.id) { calls += 1 } }
      assert_equal 1, calls
    end
  end

  test "transient failures have a persisted limit across different job instances" do
    Shopify::WebhookDelivery::MAX_ATTEMPTS.times do |i|
      job = ShopifyWebhookJob.new
      assert_no_enqueued_jobs do
        job.send(:process_delivery, @log.id) { raise "Temporary outage" }
      end
      assert_equal i + 1, @log.reload.delivery_attempts
      assert_equal "retry_wait", @log.delivery_state if i < 4
      ShopifyWebhookJob.new.send(:process_delivery, @log.id) { flunk "Early duplicate executed" }
      travel 40.minutes
    end
    assert_equal "needs_review", @log.reload.delivery_state
    assert_nil @log.next_attempt_at
    assert_no_enqueued_jobs(only: ShopifyOrderImportJob) { RecoverShopifyWebhooksJob.perform_now }
    assert_equal false, ShopifyWebhookJob.get_sidekiq_options["retry"]
  ensure
    travel_back
  end

  test "missing order goes straight to review and old jobs do not revive it" do
    ShopifyWebhookJob.new.send(:process_delivery, @log.id) { raise ImportOrderService::OrderUnavailable, "Order not found with ID: 123" }
    assert_equal "needs_review", @log.reload.delivery_state
    assert_equal 1, @log.delivery_attempts
    assert_nil @log.processed_at
    travel 1.day do
      assert_no_enqueued_jobs(only: ShopifyOrderImportJob) { RecoverShopifyWebhooksJob.perform_now }
      ShopifyWebhookJob.new.send(:process_delivery, @log.id) { flunk "Permanent failure revived" }
    end
  end

  test "Shopify null order is permanent but a malformed response is retryable" do
    service = ImportOrderService.new(store: @store, order_id: 123)
    client = Object.new
    client.define_singleton_method(:query) { |**| Struct.new(:body).new({ "data" => { "order" => nil } }) }
    ShopifyAPI::Clients::Graphql::Admin.stub(:new, client) do
      assert_raises(ImportOrderService::OrderUnavailable) { service.call }
    end
    client.define_singleton_method(:query) { |**| Struct.new(:body).new({}) }
    ShopifyAPI::Clients::Graphql::Admin.stub(:new, client) do
      assert_raises(Shopify::Response::Error) { service.call }
    end
  end

  test "retirement records actor and reason and prevents queued execution" do
    Shopify::WebhookDelivery.enqueue(@log)
    job = ShopifyWebhookJob.new
    job.job_id = @log.reload.delivery_job_id
    @log.retire!(user: @user, reason: "Confirmed fulfilled in Shopify")
    assert_equal "retired", @log.reload.delivery_state
    assert_equal @user.id, @log.retired_by_user_id
    assert_equal "Confirmed fulfilled in Shopify", @log.retirement_reason
    assert @log.retired_at
    job.send(:process_delivery, @log.id) { flunk "Retired delivery executed" }
    travel 40.days do
      WebhookLog.cleanup_old_records!
      assert WebhookLog.exists?(@log.id), "Retirement audit must be retained"
    end
  end

  test "retirement requires a reason and cannot retire a completed delivery" do
    assert_raises(ArgumentError) { @log.retire!(user: @user, reason: " ") }
    @log.update!(processed_at: Time.current)
    assert_raises(ArgumentError) { @log.retire!(user: @user, reason: "Done") }
  end

  test "invalid payload is quarantined instead of repeatedly recovered" do
    @log.update!(payload: {})
    assert_no_enqueued_jobs(only: ShopifyOrderImportJob) { Shopify::WebhookDelivery.enqueue(@log) }
    assert_equal "needs_review", @log.reload.delivery_state
    assert_match "Missing order ID", @log.error_message
  end
end
