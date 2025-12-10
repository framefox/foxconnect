# Manages inventory location for product variants in Shopify.
# Used to move products to/from the Framefox fulfillment service location
# when fulfillment is enabled/disabled in FoxConnect.
#
# Usage:
#   service = InventoryActivationService.new(product_variant)
#   service.activate_at_fulfillment_location!   # Enable fulfillment
#   service.deactivate_from_fulfillment_location! # Disable fulfillment
#
class InventoryActivationService
  attr_reader :product_variant, :store, :session, :errors

  # Print-on-demand = effectively infinite stock
  INFINITE_STOCK_QUANTITY = 999_999

  def initialize(product_variant)
    @product_variant = product_variant
    @store = product_variant.product.store
    @errors = []

    unless store.shopify?
      raise ArgumentError, "Inventory activation is only supported for Shopify stores"
    end

    unless store.active?
      raise ShopifyIntegration::InactiveStoreError, "Cannot activate inventory for inactive store: #{store.name}"
    end

    @session = ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  # Move inventory to our fulfillment service location
  # This enables "Request fulfillment" for orders containing this variant
  def activate_at_fulfillment_location!
    unless store.shopify_fulfillment_location_id.present?
      Rails.logger.warn "Fulfillment service not registered for store: #{store.name}"
      return { success: false, error: "Fulfillment service not registered. Please reconnect your store." }
    end

    inventory_item_id = fetch_inventory_item_id
    unless inventory_item_id
      return { success: false, error: "Could not fetch inventory item ID" }
    end

    Rails.logger.info "Activating inventory for variant #{product_variant.id} at fulfillment location"

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
    response = client.query(
      query: inventory_activate_mutation,
      variables: {
        inventoryItemId: inventory_item_id,
        locationId: store.shopify_fulfillment_location_id,
        available: INFINITE_STOCK_QUANTITY
      }
    )

    user_errors = response.body.dig("data", "inventoryActivate", "userErrors") || []

    if user_errors.any?
      error_message = user_errors.map { |e| "#{e['field']}: #{e['message']}" }.join(", ")
      @errors << error_message
      Rails.logger.error "Failed to activate inventory: #{error_message}"
      return { success: false, error: error_message }
    end

    inventory_level = response.body.dig("data", "inventoryActivate", "inventoryLevel")
    if inventory_level
      Rails.logger.info "Successfully activated inventory at fulfillment location: #{inventory_level['id']}"
      { success: true, inventory_level_id: inventory_level["id"] }
    else
      error = response.body.dig("errors")&.map { |e| e["message"] }&.join(", ") || "Unknown error"
      @errors << error
      { success: false, error: error }
    end
  rescue StandardError => e
    @errors << e.message
    Rails.logger.error "Exception activating inventory: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  # Remove inventory from our fulfillment service location
  # This disables "Request fulfillment" for orders containing this variant
  def deactivate_from_fulfillment_location!
    unless store.shopify_fulfillment_location_id.present?
      Rails.logger.warn "Fulfillment service not registered for store: #{store.name}"
      return { success: false, error: "Fulfillment service not registered" }
    end

    inventory_item_id = fetch_inventory_item_id
    unless inventory_item_id
      return { success: false, error: "Could not fetch inventory item ID" }
    end

    Rails.logger.info "Deactivating inventory for variant #{product_variant.id} from fulfillment location"

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # First, get the inventory level ID at our fulfillment location
    inventory_level_id = fetch_inventory_level_id(client, inventory_item_id, store.shopify_fulfillment_location_id)

    unless inventory_level_id
      # Inventory is not active at our location - nothing to deactivate
      Rails.logger.info "Inventory not active at fulfillment location, nothing to deactivate"
      return { success: true, message: "Not active at fulfillment location" }
    end

    # Deactivate inventory at our fulfillment location
    response = client.query(
      query: inventory_deactivate_mutation,
      variables: { inventoryLevelId: inventory_level_id }
    )

    user_errors = response.body.dig("data", "inventoryDeactivate", "userErrors") || []

    if user_errors.any?
      error_message = user_errors.map { |e| "#{e['field']}: #{e['message']}" }.join(", ")
      @errors << error_message
      Rails.logger.error "Failed to deactivate inventory: #{error_message}"
      return { success: false, error: error_message }
    end

    Rails.logger.info "Successfully deactivated inventory from fulfillment location"
    { success: true }
  rescue StandardError => e
    @errors << e.message
    Rails.logger.error "Exception deactivating inventory: #{e.message}"
    { success: false, error: e.message }
  end

  private

  def fetch_inventory_item_id
    # Try to get from stored metadata first
    inventory_item_id = product_variant.metadata.dig("shopify_data", "inventoryItem", "id")
    return inventory_item_id if inventory_item_id.present?

    # Otherwise fetch from Shopify API
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
    response = client.query(
      query: fetch_inventory_item_query,
      variables: { variantId: product_variant.shopify_gid }
    )

    inventory_item_id = response.body.dig("data", "productVariant", "inventoryItem", "id")

    # Cache for future use
    if inventory_item_id
      metadata = product_variant.metadata || {}
      metadata["shopify_data"] ||= {}
      metadata["shopify_data"]["inventoryItem"] ||= {}
      metadata["shopify_data"]["inventoryItem"]["id"] = inventory_item_id
      product_variant.update_column(:metadata, metadata)
    end

    inventory_item_id
  end

  def fetch_inventory_level_id(client, inventory_item_id, location_id)
    response = client.query(
      query: fetch_inventory_level_query,
      variables: {
        inventoryItemId: inventory_item_id,
        locationId: location_id
      }
    )

    response.body.dig("data", "inventoryItem", "inventoryLevel", "id")
  end

  def inventory_activate_mutation
    <<~GRAPHQL
      mutation inventoryActivate($inventoryItemId: ID!, $locationId: ID!, $available: Int) {
        inventoryActivate(
          inventoryItemId: $inventoryItemId,
          locationId: $locationId,
          available: $available
        ) {
          inventoryLevel {
            id
            quantities(names: ["available"]) {
              name
              quantity
            }
            location {
              id
              name
            }
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end

  def fetch_inventory_item_query
    <<~GRAPHQL
      query FetchInventoryItem($variantId: ID!) {
        productVariant(id: $variantId) {
          id
          inventoryItem {
            id
          }
        }
      }
    GRAPHQL
  end

  def fetch_inventory_level_query
    <<~GRAPHQL
      query FetchInventoryLevelAtLocation($inventoryItemId: ID!, $locationId: ID!) {
        inventoryItem(id: $inventoryItemId) {
          inventoryLevel(locationId: $locationId) {
            id
          }
        }
      }
    GRAPHQL
  end

  def inventory_deactivate_mutation
    <<~GRAPHQL
      mutation inventoryDeactivate($inventoryLevelId: ID!) {
        inventoryDeactivate(inventoryLevelId: $inventoryLevelId) {
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end
end
