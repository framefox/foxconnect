require "test_helper"
require "minitest/mock"

class Shopify::OnboardingTest < ActiveSupport::TestCase
  Response = Struct.new(:body)
  class Client
    attr_reader :calls
    def initialize(*bodies)
      @bodies, @calls = bodies, []
    end
    def query(query:, variables: {})
      @calls << { query: query, variables: variables }
      Response.new(@bodies.shift || raise("Unexpected query"))
    end
  end

  test "fulfillment decisions reject top-level API errors and missing data" do
    service = FulfillmentRequestHandlerService.allocate
    service.instance_variable_set(:@errors, [])
    %w[accept_fulfillment_request accept_cancellation_request reject_cancellation_request].each do |method|
      [ { "errors" => [ { "message" => "Access denied" } ] }, { "data" => {} } ].each do |body|
        args = [ Client.new(body), "gid://shopify/FulfillmentOrder/1" ]
        args << "Requested" unless method == "accept_fulfillment_request"
        assert_raises(Shopify::Response::Error) { service.send(method, *args) }
      end
    end
  end

  test "fulfillment query paginates before changing request status" do
    service = FulfillmentRequestHandlerService.allocate
    first = connection([ 1, 2 ], next_page: true, cursor: "next")
    last = connection([ 3 ])
    client = Client.new({ "data" => { "assignedFulfillmentOrders" => first } }, { "data" => { "assignedFulfillmentOrders" => last } })
    edges = service.send(:fetch_assigned_orders, client, "FULFILLMENT_REQUESTED")
    assert_equal [ 1, 2, 3 ], edges.map { |edge| edge["node"]["id"] }
    assert_equal "next", client.calls.last[:variables][:after]
    refute_match(/shop\s*\{/, client.calls.first[:query])
  end

  test "pagination fails on missing or repeating cursor instead of looping" do
    assert_raises(Shopify::Response::Error) { Shopify::Pagination.collect(connection([ 1 ], next_page: true)) }
    page = connection([ 1 ], next_page: true, cursor: "same")
    assert_raises(Shopify::Response::Error) { Shopify::Pagination.collect(page) { page } }
  end

  test "inventory activation sends a stable caller-supplied idempotency key" do
    store = Struct.new(:shopify_fulfillment_location_id, :name).new("location", "Test")
    variant = Struct.new(:id).new(1)
    service = InventoryActivationService.allocate
    service.instance_variable_set(:@store, store)
    service.instance_variable_set(:@product_variant, variant)
    service.instance_variable_set(:@errors, [])
    body = { "data" => { "inventoryActivate" => { "inventoryLevel" => { "id" => "level" }, "userErrors" => [] } } }
    client = Client.new(body, body)
    service.stub(:fetch_inventory_item_id, "inventory-item") do
      ShopifyAPI::Clients::Graphql::Admin.stub(:new, client) do
        2.times { assert service.activate_at_fulfillment_location!(idempotency_key: "operation-1")[:success] }
      end
    end
    assert client.calls.all? { |call| call[:variables][:idempotencyKey] == "operation-1" }
    assert_includes client.calls.first[:query], "@idempotent(key: $idempotencyKey)"
  end

  test "outbound fulfillment hydrates both fulfillment-order and line-item pages" do
    lines1 = connection([ 11 ], next_page: true, cursor: "lines-next")
    lines2 = connection([ 12 ])
    orders1 = { "edges" => [ { "node" => { "id" => "fo-1", "lineItems" => lines1 } } ],
      "pageInfo" => { "hasNextPage" => true, "endCursor" => "orders-next" } }
    orders2 = { "edges" => [ { "node" => { "id" => "fo-2", "lineItems" => connection([ 21 ]) } } ],
      "pageInfo" => { "hasNextPage" => false } }
    client = Client.new(
      { "data" => { "order" => { "fulfillmentOrders" => orders1 } } },
      { "data" => { "order" => { "fulfillmentOrders" => orders2 } } },
      { "data" => { "fulfillmentOrder" => { "lineItems" => lines2 } } }
    )
    service = OutboundFulfillmentService.allocate
    service.instance_variable_set(:@order, Struct.new(:external_id).new("1"))
    service.instance_variable_set(:@shopify_client, client)
    data = service.send(:fetch_shopify_fulfillment_orders)
    nodes = data["fulfillmentOrders"]["edges"].map { |edge| edge["node"] }
    assert_equal [ "fo-1", "fo-2" ], nodes.map { |node| node["id"] }
    assert_equal [ 11, 12 ], nodes.first["lineItems"]["edges"].map { |edge| edge["node"]["id"] }
    assert_equal "orders-next", client.calls[1][:variables][:after]
    assert_equal({ id: "fo-1", after: "lines-next" }, client.calls[2][:variables])
  end

  test "inventory job preserves the operation key across failure and retry" do
    variant = Struct.new(:metadata, :product) do
      def fulfilment_active?; true; end
    end.new({ "inventory_operation_key" => "operation-1" }, Struct.new(:store).new(Struct.new(:active?).new(true)))
    keys = []
    service = Object.new
    service.define_singleton_method(:activate_at_fulfillment_location!) do |idempotency_key:|
      keys << idempotency_key
      { success: keys.length > 1, error: "Temporary failure" }
    end
    ProductVariant.stub(:find_by, variant) do
      InventoryActivationService.stub(:new, service) do
        job = SyncShopifyInventoryLocationJob.new
        assert_raises(Shopify::Response::Error) { job.perform(123, true, "operation-1") }
        job.perform(123, true, "operation-1")
        variant.metadata["inventory_operation_key"] = "newer-operation"
        job.perform(123, true, "operation-1")
      end
    end
    assert_equal [ "operation-1", "operation-1" ], keys
  end

  test "inventory deactivation does not treat an API error as an inactive location" do
    service = InventoryActivationService.allocate
    client = Client.new({ "errors" => [ { "message" => "Access denied" } ] })
    assert_raises(Shopify::Response::Error) do
      service.send(:fetch_inventory_level_id, client, "inventory-item", "location")
    end
  end

  test "production and development app configuration match runtime versions and permissions" do
    %w[shopify.app.toml shopify.app.production.toml].each do |filename|
      source = Rails.root.join(filename).read
      assert_equal ShopifyApp.configuration.api_version, source[/api_version = "([^"]+)"/, 1]
      scopes = ShopifyAPI::Auth::AuthScopes.new(source[/^scopes = "([^"]+)"/, 1])
      assert_equal ShopifyAPI::Auth::AuthScopes.new(ShopifyApp.configuration.scope), scopes
      assert_includes source, 'topics = ["products/delete"]'
      assert_includes source, 'topics = ["fulfillment_orders/fulfillment_request_submitted"]'
      assert_includes source, 'topics = ["fulfillment_orders/cancellation_request_submitted"]'
    end
  end

  test "SDK and application target the same supported API with expiring offline tokens" do
    assert_equal "2026-10", ShopifyAPI::Context.api_version
    assert_equal ShopifyApp.configuration.api_version, ShopifyAPI::Context.api_version
    assert ShopifyAPI::Context.expiring_offline_access_tokens
  end

  private

  def connection(ids, next_page: false, cursor: nil)
    { "edges" => ids.map { |id| { "node" => { "id" => id } } },
      "pageInfo" => { "hasNextPage" => next_page, "endCursor" => cursor } }
  end
end
