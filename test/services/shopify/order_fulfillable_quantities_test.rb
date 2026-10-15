require "test_helper"
require "minitest/mock"

class Shopify::OrderFulfillableQuantitiesTest < ActiveSupport::TestCase
  Response = Struct.new(:body)
  class Client
    attr_reader :calls
    def initialize(*responses)
      @responses = responses
      @calls = []
    end
    def query(query:, variables:)
      @calls << variables
      Response.new(@responses.shift || raise("Unexpected request"))
    end
  end

  test "only ready remaining quantities count across split fulfillment orders" do
    orders = [
      fulfillment("OPEN", [ line("a", 2), line("done", 0) ]),
      fulfillment("IN_PROGRESS", [ line("a", 1) ]),
      *%w[SCHEDULED ON_HOLD CANCELLED CLOSED INCOMPLETE].map { |status| fulfillment(status, [ line("a", 50), line(status, 5) ]) }
    ]
    client = Client.new(order_response(connection(orders)))
    quantities = Shopify::OrderFulfillableQuantities.new(client).call("order")
    assert_equal 3, quantities["a"]
    assert_equal 0, quantities["done"]
    assert_equal 0, quantities["non-fulfillable"]
    %w[SCHEDULED ON_HOLD CANCELLED CLOSED INCOMPLETE].each { |status| assert_equal 0, quantities[status] }
  end

  test "paginates both fulfillment orders and their line items" do
    first = fulfillment("OPEN", [ line("a", 1) ])
    first["lineItems"] = connection([ line("a", 1) ], "lines-next")
    client = Client.new(
      order_response(connection([ first ], "orders-next")),
      order_response(connection([ fulfillment("IN_PROGRESS", [ line("a", 2) ]) ])),
      { "data" => { "fulfillmentOrder" => { "lineItems" => connection([ line("b", 3) ]) } } }
    )
    assert_equal({ "a" => 3, "b" => 3 }, Shopify::OrderFulfillableQuantities.new(client).call("order"))
    assert_equal "orders-next", client.calls[1][:after]
    assert_equal "lines-next", client.calls[2][:after]
  end

  test "does not interpret inaccessible or missing fulfillment data as zero" do
    [
      { "data" => { "order" => nil }, "errors" => [ { "message" => "Access denied" } ] },
      { "data" => { "order" => { "fulfillmentOrders" => nil } } }
    ].each do |body|
      assert_raises(Shopify::Response::Error) { Shopify::OrderFulfillableQuantities.new(Client.new(body)).call("order") }
    end
    first = fulfillment("OPEN", [ line("a", 1) ])
    first["lineItems"] = connection([ line("a", 1) ], "next")
    client = Client.new(order_response(connection([ first ])), { "errors" => [ { "message" => "Throttled" } ] })
    assert_raises(Shopify::Response::Error) { Shopify::OrderFulfillableQuantities.new(client).call("order") }
  end

  test "resync supplies computed quantities and never applies a partial failed fetch" do
    store = Struct.new(:name).new("Test")
    def store.shopify? = true
    def store.active? = true
    existing = Struct.new(:external_id).new("1")
    service = ImportOrderService.allocate
    service.instance_variable_set(:@store, store)
    data = { "id" => "order", "lineItems" => connection([ { "id" => "a", "quantity" => 10 }, { "id" => "scheduled", "quantity" => 5 } ]) }
    client = Client.new({ "data" => { "order" => data } }, order_response(connection([
      fulfillment("OPEN", [ line("a", 2) ]), fulfillment("SCHEDULED", [ line("scheduled", 5) ])
    ])))
    applied = nil
    service.stub(:resync_order_data, ->(_order, payload) { applied = payload }) do
      ShopifyAPI::Clients::Graphql::Admin.stub(:new, client) { service.resync_order(existing) }
    end
    assert_equal [ 2, 0 ], applied["lineItems"]["edges"].map { |e| e["node"]["remainingFulfillableQuantity"] }
    assert_equal [ 10, 5 ], applied["lineItems"]["edges"].map { |e| e["node"]["quantity"] }

    missing = { "lineItems" => connection([ { "id" => "hidden", "unfulfilledQuantity" => 2 } ]) }
    hidden_client = Client.new({ "data" => { "order" => missing } }, order_response(connection([])))
    service.stub(:resync_order_data, ->(*) { flunk "Must not archive work hidden by scopes" }) do
      ShopifyAPI::Clients::Graphql::Admin.stub(:new, hidden_client) do
        assert_raises(Shopify::Response::Error) { service.resync_order(existing) }
      end
    end

    client = Client.new({ "data" => { "order" => data } }, { "errors" => [ { "message" => "Access denied" } ] })
    service.stub(:resync_order_data, ->(*) { flunk "Must not modify local items after incomplete fetch" }) do
      ShopifyAPI::Clients::Graphql::Admin.stub(:new, client) do
        assert_raises(Shopify::Response::Error) { service.resync_order(existing) }
      end
    end
  end

  private

  def line(id, quantity)
    { "lineItem" => { "id" => id }, "remainingQuantity" => quantity }
  end

  def fulfillment(status, lines)
    { "id" => "fulfillment-#{status}", "status" => status, "lineItems" => connection(lines) }
  end

  def connection(nodes, cursor = nil)
    { "edges" => nodes.map { |node| { "node" => node } }, "pageInfo" => { "hasNextPage" => cursor.present?, "endCursor" => cursor } }
  end

  def order_response(orders)
    { "data" => { "order" => { "fulfillmentOrders" => orders } } }
  end
end
