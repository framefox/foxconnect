require "test_helper"
require "minitest/mock"

class Shopify::CountryBlockTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    org = Organization.create!(name: "Country block test")
    user = User.create!(email: "country-#{SecureRandom.hex(4)}@example.com", organization: org, country: "NZ")
    @store = Store.create!(organization: org, created_by_user: user, name: "Country Store", platform: "shopify",
      shopify_domain: "country-#{SecureRandom.hex(4)}.myshopify.com", shopify_token: "token", access_scopes: "read_orders")
    @data = { "id" => "gid://shopify/Order/123", "name" => "#123", "shippingAddress" => { "countryCodeV2" => "AU" } }
    @service = ImportOrderService.allocate
    @service.instance_variable_set(:@store, @store)
    clear_enqueued_jobs
  end

  test "repeated imports and resyncs create no orders" do
    assert_no_difference("Order.count") do
      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        2.times { assert_raises(ImportOrderService::CountryBlocked) { @service.send(:import_order, @data) } }
        assert_raises(ImportOrderService::CountryBlocked) { @service.send(:resync_order_data, nil, @data) }
      end
    end
  end

  test "unsupported countries are terminal but a corrected address can pass validation" do
    @data["shippingAddress"]["countryCodeV2"] = "US"
    assert_raises(ImportOrderService::CountryBlocked) { @service.send(:validate_country!, @data) }
    @data["shippingAddress"]["countryCodeV2"] = "NZ"
    assert_equal "NZ", @service.send(:validate_country!, @data)
  end

  test "blocked delivery completes and existing queued retries do nothing" do
    log = WebhookLog.create!(topic: "orders/create", status_code: 202, shop_domain: @store.shopify_domain, payload: { id: 123 })
    calls = 0
    @service.define_singleton_method(:call) do
      calls += 1
      send(:import_order, @data_for_test)
    end
    @service.instance_variable_set(:@data_for_test, @data)
    ImportOrderService.stub(:new, ->(**) { @service }) do
      assert_no_enqueued_jobs only: ActionMailer::MailDeliveryJob do
        2.times { ShopifyOrderImportJob.perform_now(@store.id, 123, log.id) }
      end
    end
    assert_equal 1, calls
    assert_equal 200, log.reload.status_code
    assert log.processed_at
    assert_match "Blocked by country policy", log.error_message
    travel 20.minutes do
      assert_no_enqueued_jobs(only: ShopifyOrderImportJob) { RecoverShopifyWebhooksJob.perform_now }
    end
  end

  test "fulfillment batches skip country blocks and continue processing other requests" do
    handler = FulfillmentRequestHandlerService.allocate
    handler.instance_variable_set(:@store, @store)
    handler.instance_variable_set(:@errors, [])
    orders = [ { "node" => { "id" => "blocked" } }, { "node" => { "id" => "allowed" } } ]
    accepted = []
    handler.stub(:fetch_assigned_orders, orders) do
      handler.stub(:ensure_order_imported, ->(fo) { fo["id"] == "blocked" ? :country_blocked : Object.new }) do
        handler.stub(:accept_fulfillment_request, ->(_client, id) { accepted << id; { success: true } }) do
          ShopifyAPI::Clients::Graphql::Admin.stub(:new, Object.new) do
            result = handler.accept_pending_requests!
            assert result[:success]
            assert_equal 1, result[:accepted_count]
          end
        end
      end
    end
    assert_equal [ "allowed" ], accepted
  end
end
