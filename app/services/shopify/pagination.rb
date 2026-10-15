module Shopify
  module Pagination
    def self.collect(connection)
      raise Response::Error, "Missing Shopify connection" unless connection
      edges = Array(connection["edges"]).dup
      seen = []
      while connection.dig("pageInfo", "hasNextPage")
        cursor = connection.dig("pageInfo", "endCursor")
        raise Response::Error, "Shopify pagination did not advance" if cursor.blank? || seen.include?(cursor)
        seen << cursor
        connection = yield(cursor)
        raise Response::Error, "Missing Shopify page" unless connection
        edges.concat(Array(connection["edges"]))
      end
      { "edges" => edges, "pageInfo" => { "hasNextPage" => false } }
    end
  end
end
