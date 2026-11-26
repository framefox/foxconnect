require "test_helper"
require "minitest/mock"

class ShopifyProductSyncConcurrencyTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  # Real, independent Postgres sessions must see committed fixture records.
  self.use_transactional_tests = false

  setup do
    @organization = Organization.create!(name: "Sync concurrency test")
    @user = User.create!(organization: @organization, email: "sync-#{SecureRandom.hex(8)}@example.com")
    @store = Store.create!(organization: @organization, created_by_user: @user, name: "Sync concurrency test",
      platform: "shopify", shopify_domain: "#{SecureRandom.hex(8)}.myshopify.com",
      shopify_token: "test", access_scopes: "read_products")
    config = ActiveRecord::Base.connection.raw_connection.conninfo_hash
    @other = PG.connect(config.slice(:host, :port, :dbname, :user, :password))
    @other.exec("SET statement_timeout = '1s'")
  end

  teardown do
    @other&.close
    WebhookLog.where(store: @store).delete_all
    @store&.destroy!
    @user&.destroy!
    @organization&.destroy!
  end

  test "a webhook can insert while a catalogue batch is running" do
    service = Object.new
    service.define_singleton_method(:sync_product_batch) { |**| }
    check = lambda do |**|
      # This is the FK lock that waited 166 seconds during the incident.
      result = @other.exec_params(<<~SQL, [ @store.id ])
        INSERT INTO webhook_logs (topic, store_id, created_at, updated_at)
        VALUES ('orders/create', $1, NOW(), NOW()) RETURNING id
      SQL
      assert_equal 1, result.ntuples
      assert_equal "2s", ActiveRecord::Base.connection.select_value("SHOW lock_timeout")
      assert_equal "15s", ActiveRecord::Base.connection.select_value("SHOW statement_timeout")
      { full_reconciliation_completed: true, next_cursor: nil }
    end
    before = ActiveRecord::Base.connection.select_value("SHOW statement_timeout")
    service.stub(:sync_product_batch, check) do
      ShopifyProductSyncService.stub(:new, service) { ShopifyProductSyncJob.perform_now(@store) }
    end
    assert_equal "archive", @store.reload.product_sync_state["phase"]
    assert_equal before, ActiveRecord::Base.connection.select_value("SHOW statement_timeout")
    assert_equal "t", @other.exec_params("SELECT pg_try_advisory_lock(74005, $1::integer)", [ @store.id ]).getvalue(0, 0)
  end

  test "a concurrent sync skips the batch without waiting or spawning another chain" do
    @other.exec_params("SELECT pg_advisory_lock(74005, $1::integer)", [ @store.id ])
    ShopifyProductSyncService.stub(:new, ->(*) { flunk "Overlapping batch executed" }) do
      assert_no_enqueued_jobs(only: ShopifyProductSyncJob) { ShopifyProductSyncJob.perform_now(@store) }
    end
    assert_empty @store.reload.product_sync_state
  end

  test "database timeout rolls back the checkpoint and releases the sync lock" do
    service = Object.new
    service.define_singleton_method(:sync_product_batch) do |**|
      connection = ActiveRecord::Base.connection
      connection.execute("SET LOCAL statement_timeout = '20ms'")
      connection.execute("SELECT pg_sleep(1)")
    end
    ShopifyProductSyncService.stub(:new, service) do
      assert_raises(ActiveRecord::QueryCanceled) { ShopifyProductSyncJob.perform_now(@store) }
    end
    assert_empty @store.reload.product_sync_state
    assert_equal "t", @other.exec_params("SELECT pg_try_advisory_lock(74005, $1::integer)", [ @store.id ]).getvalue(0, 0)
  end
end
