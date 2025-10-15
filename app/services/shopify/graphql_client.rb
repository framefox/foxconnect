module Shopify
  class GraphqlClient
    attr_reader :order

    def initialize(order:)
      @order = order
    end

    def query(query_string, variables)
      # Use country-specific Shopify credentials from configuration
      config = order.country_config

      # Fallback to NZ environment variables if no config
      shop = config ? config["shopify_domain"] : ENV["remote_shopify_domain_nz"]
      token = config ? config["shopify_access_token"] : ENV["remote_shopify_access_token_nz"]

      session = ShopifyAPI::Auth::Session.new(
        shop: shop,
        access_token: token
      )

      client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
      client.query(query: query_string, variables: variables)
    rescue => e
      Rails.logger.error "Shopify GraphQL request failed: #{e.message}"
      Rails.logger.error "Shop: #{shop}"
      Rails.logger.error "Access token present: #{token.present?}"
      nil
    end

    # Helper method to build Shopify GID format
    def build_gid(resource_type, id)
      # If ID already has gid:// prefix, return as-is
      return id if id.to_s.start_with?("gid://shopify/")

      # Otherwise, build the full GID
      "gid://shopify/#{resource_type}/#{id}"
    end
  end
end
