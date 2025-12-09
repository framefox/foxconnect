# Service for syncing variant cost to Shopify using GraphQL API
#
# This service updates the inventory item cost (unit cost) for a Shopify variant
# when a variant mapping is created or updated.
#
# Usage Examples:
#
# # Basic usage - sync single variant cost
# service = ShopifyVariantCostSyncService.new(store)
# result = service.sync_variant_cost(
#   shopify_variant_id: "12345",
#   shopify_product_id: "67890",
#   cost: 29.99
# )
#
# # Using store convenience method
# store.sync_variant_cost(
#   shopify_variant_id: "12345",
#   shopify_product_id: "67890",
#   cost: 29.99
# )
#
class ShopifyVariantCostSyncService
  attr_reader :store, :session

  def initialize(store)
    @store = store
    raise ArgumentError, "Store must be a Shopify store" unless store.shopify?
    raise ArgumentError, "Store must be connected to Shopify" unless store.shopify_token.present?

    @session = store.shopify_session
  end

  # Syncs the cost to a specific Shopify variant's inventory item
  # @param shopify_variant_id [String, Integer] The Shopify variant ID
  # @param shopify_product_id [String, Integer] The Shopify product ID
  # @param cost [Float, BigDecimal] The cost in dollars (shop currency)
  # @return [Hash] Result with success status and details
  def sync_variant_cost(shopify_variant_id:, shopify_product_id:, cost:)
    Rails.logger.info "Starting variant cost sync for variant #{shopify_variant_id} with cost: #{cost}"

    begin
      result = update_variant_cost(shopify_product_id, shopify_variant_id, cost)

      if result[:success]
        Rails.logger.info "✅ Successfully synced cost #{cost} for variant #{shopify_variant_id}"
      else
        Rails.logger.error "❌ Failed to sync cost for variant #{shopify_variant_id}: #{result[:error]}"
      end

      result

    rescue => e
      Rails.logger.error "❌ Error syncing variant cost: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")

      {
        success: false,
        error: e.message
      }
    end
  end

  private

  def graphql_client
    @graphql_client ||= ShopifyAPI::Clients::Graphql::Admin.new(session: session)
  end

  # Updates the variant cost using the productVariantsBulkUpdate mutation
  def update_variant_cost(shopify_product_id, shopify_variant_id, cost)
    Rails.logger.info "Updating cost for variant #{shopify_variant_id} to #{cost}"

    mutation = <<~GRAPHQL
      mutation ProductVariantsBulkUpdate($productId: ID!, $variants: [ProductVariantsBulkInput!]!) {
        productVariantsBulkUpdate(productId: $productId, variants: $variants) {
          product {
            id
          }
          productVariants {
            id
            inventoryItem {
              id
              unitCost {
                amount
                currencyCode
              }
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL

    variables = {
      "productId" => "gid://shopify/Product/#{shopify_product_id}",
      "variants" => [{
        "id" => "gid://shopify/ProductVariant/#{shopify_variant_id}",
        "inventoryItem" => {
          "cost" => cost.to_s
        }
      }]
    }

    response = graphql_client.query(query: mutation, variables: variables)

    if response.body.dig("data", "productVariantsBulkUpdate", "userErrors")&.empty?
      updated_variant = response.body.dig("data", "productVariantsBulkUpdate", "productVariants")&.first
      unit_cost = updated_variant&.dig("inventoryItem", "unitCost")

      Rails.logger.info "Successfully updated variant #{shopify_variant_id} cost to #{unit_cost&.dig('amount')} #{unit_cost&.dig('currencyCode')}"

      {
        success: true,
        variant_id: shopify_variant_id,
        cost: cost,
        unit_cost: unit_cost
      }
    else
      errors = response.body.dig("data", "productVariantsBulkUpdate", "userErrors") || response.body["errors"] || []
      error_message = extract_graphql_errors(errors)
      Rails.logger.error "Failed to update variant #{shopify_variant_id} cost: #{error_message}"

      # Check if this is an auth error and flag the store
      error_handler = StoreConnectionErrorHandler.new(store)
      error_handler.handle_error(error_message)

      {
        success: false,
        error: error_message
      }
    end
  rescue ShopifyAPI::Errors::HttpResponseError => e
    Rails.logger.error "Error updating variant cost: #{e.message}"

    # Handle auth errors
    error_handler = StoreConnectionErrorHandler.new(store)
    error_handler.handle_error(e.message)

    {
      success: false,
      error: e.message
    }
  rescue => e
    Rails.logger.error "Error updating variant cost: #{e.message}"
    {
      success: false,
      error: e.message
    }
  end

  # Extracts error message from GraphQL response
  def extract_graphql_errors(errors)
    if errors.is_a?(Array)
      errors.map { |error| error["message"] || error.to_s }.join(", ")
    elsif errors.is_a?(Hash)
      errors["message"] || errors.to_s
    else
      "Unknown error occurred"
    end
  end
end

