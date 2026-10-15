module Shopify
  # Only work that can be fulfilled now counts. Scheduled and held work must
  # become OPEN first; closed/cancelled/incomplete orders cannot be fulfilled.
  class OrderFulfillableQuantities
    READY_STATUSES = %w[OPEN IN_PROGRESS].freeze

    def initialize(client)
      @client = client
    end

    def call(order_gid)
      fetch_orders = lambda do |cursor|
        response = @client.query(query: orders_query, variables: { id: order_gid, after: cursor })
        Response.data!(response, "order").fetch("fulfillmentOrders")
      end
      orders = Pagination.collect(fetch_orders.call(nil), &fetch_orders)
      quantities = Hash.new(0)
      orders.fetch("edges").each do |edge|
        order = edge.fetch("node")
        ready = READY_STATUSES.include?(order.fetch("status"))

        lines = Pagination.collect(order.fetch("lineItems")) do |cursor|
          response = @client.query(query: lines_query, variables: { id: order.fetch("id"), after: cursor })
          Response.data!(response, "fulfillmentOrder").fetch("lineItems")
        end
        lines.fetch("edges").each do |line_edge|
          line = line_edge.fetch("node")
          quantities[line.fetch("lineItem").fetch("id")] += ready ? line.fetch("remainingQuantity") : 0
        end
      end
      quantities
    end

    private

    def orders_query
      <<~GRAPHQL
        query OrderFulfillableQuantities($id: ID!, $after: String) {
          order(id: $id) {
            fulfillmentOrders(first: 10, after: $after) {
              pageInfo { hasNextPage endCursor }
              edges { node {
                id status
                lineItems(first: 50) {
                  pageInfo { hasNextPage endCursor }
                  edges { node { lineItem { id } remainingQuantity } }
                }
              } }
            }
          }
        }
      GRAPHQL
    end

    def lines_query
      <<~GRAPHQL
        query RemainingFulfillmentLines($id: ID!, $after: String) {
          fulfillmentOrder(id: $id) {
            lineItems(first: 250, after: $after) {
              pageInfo { hasNextPage endCursor }
              edges { node { lineItem { id } remainingQuantity } }
            }
          }
        }
      GRAPHQL
    end
  end
end
