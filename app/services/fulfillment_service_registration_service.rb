# Registers Framefox Connect as a fulfillment service on a Shopify store.
# This creates a dedicated location for our app and enables "Request fulfillment" button.
#
# Usage:
#   service = FulfillmentServiceRegistrationService.new(store)
#   result = service.register!
#
class FulfillmentServiceRegistrationService
  attr_reader :store, :session, :errors

  FULFILLMENT_SERVICE_NAME = "Framefox Connect".freeze

  def initialize(store)
    @store = store
    @errors = []

    unless store.shopify?
      raise ArgumentError, "Fulfillment service registration is only supported for Shopify stores"
    end

    unless store.active?
      raise ShopifyIntegration::InactiveStoreError, "Cannot register fulfillment service for inactive store: #{store.name}"
    end

    @session = ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  # Register as a fulfillment service on the merchant's store
  # Returns { success: true/false, fulfillment_service_id: ..., location_id: ... }
  def register!
    # Skip if already registered
    if store.shopify_fulfillment_service_id.present?
      Rails.logger.info "Fulfillment service already registered for store: #{store.name}"
      return {
        success: true,
        already_registered: true,
        fulfillment_service_id: store.shopify_fulfillment_service_id,
        location_id: store.shopify_fulfillment_location_id
      }
    end

    Rails.logger.info "Registering fulfillment service for store: #{store.name}"

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
    response = client.query(query: create_mutation, variables: create_variables)

    if response.body.dig("data", "fulfillmentServiceCreate", "fulfillmentService")
      fulfillment_service = response.body["data"]["fulfillmentServiceCreate"]["fulfillmentService"]
      fulfillment_service_id = fulfillment_service["id"]
      location_id = fulfillment_service.dig("location", "id")

      # If location ID wasn't returned, fetch it separately
      if location_id.blank?
        location_id = fetch_location_id(client, fulfillment_service_id)
      end

      # Update the location address to New Zealand
      if location_id.present?
        update_location_address(client, location_id)
      end

      # Save to store record
      store.update!(
        shopify_fulfillment_service_id: fulfillment_service_id,
        shopify_fulfillment_location_id: location_id
      )

      Rails.logger.info "Successfully registered fulfillment service: #{fulfillment_service_id}"
      Rails.logger.info "Created fulfillment location: #{location_id}"

      {
        success: true,
        fulfillment_service_id: fulfillment_service_id,
        location_id: location_id
      }
    else
      user_errors = response.body.dig("data", "fulfillmentServiceCreate", "userErrors") || []
      error_messages = user_errors.map { |e| "#{e['field']}: #{e['message']}" }.join(", ")

      if error_messages.blank?
        error_messages = response.body.dig("errors")&.map { |e| e["message"] }&.join(", ") || "Unknown error"
      end

      @errors << error_messages
      Rails.logger.error "Failed to register fulfillment service: #{error_messages}"

      { success: false, error: error_messages }
    end
  rescue StandardError => e
    @errors << e.message
    Rails.logger.error "Exception registering fulfillment service: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    { success: false, error: e.message }
  end

  # Unregister the fulfillment service (e.g., when store disconnects)
  def unregister!
    return { success: true, message: "Not registered" } unless store.shopify_fulfillment_service_id.present?

    Rails.logger.info "Unregistering fulfillment service for store: #{store.name}"

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)
    response = client.query(query: delete_mutation, variables: { id: store.shopify_fulfillment_service_id })

    if response.body.dig("data", "fulfillmentServiceDelete", "deletedId")
      store.update!(
        shopify_fulfillment_service_id: nil,
        shopify_fulfillment_location_id: nil
      )

      Rails.logger.info "Successfully unregistered fulfillment service"
      { success: true }
    else
      user_errors = response.body.dig("data", "fulfillmentServiceDelete", "userErrors") || []
      error_messages = user_errors.map { |e| "#{e['field']}: #{e['message']}" }.join(", ")

      Rails.logger.error "Failed to unregister fulfillment service: #{error_messages}"
      { success: false, error: error_messages }
    end
  rescue StandardError => e
    Rails.logger.error "Exception unregistering fulfillment service: #{e.message}"
    { success: false, error: e.message }
  end

  # Check if the fulfillment service already exists on this store
  def registered?
    store.shopify_fulfillment_service_id.present?
  end

  private

  def callback_url
    # The callback URL must be a publicly accessible URL where Shopify can reach us
    # Use FULFILLMENT_CALLBACK_HOST env var, or fall back to SHOPIFY_HOST, or production URL
    base_url = ENV.fetch("FULFILLMENT_CALLBACK_HOST") { ENV.fetch("SHOPIFY_HOST", "https://connect.framefox.com") }

    # Ensure we never use localhost for callback URLs (Shopify will reject them)
    if base_url.include?("localhost") || base_url.include?("127.0.0.1")
      base_url = "https://21e1b790d7e5-7709362242705023816.ngrok-free.app"
    end

    "#{base_url}/webhooks"
  end

  def fetch_location_id(client, fulfillment_service_id)
    query = <<~GRAPHQL
      query FetchFulfillmentServiceLocation($id: ID!) {
        fulfillmentService(id: $id) {
          location {
            id
          }
        }
      }
    GRAPHQL

    response = client.query(query: query, variables: { id: fulfillment_service_id })
    response.body.dig("data", "fulfillmentService", "location", "id")
  end

  def update_location_address(client, location_id)
    country_code = store.user&.country.presence || "NZ"
    Rails.logger.info "Updating location address to #{country_code} for location: #{location_id}"

    mutation = <<~GRAPHQL
      mutation locationEdit($id: ID!, $input: LocationEditInput!) {
        locationEdit(id: $id, input: $input) {
          location {
            id
            address {
              country
              city
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
      id: location_id,
      input: {
        address: {
          countryCode: country_code
        }
      }
    }

    response = client.query(query: mutation, variables: variables)

    user_errors = response.body.dig("data", "locationEdit", "userErrors") || []
    if user_errors.any?
      error_messages = user_errors.map { |e| "#{e['field']}: #{e['message']}" }.join(", ")
      Rails.logger.warn "Failed to update location address: #{error_messages}"
    else
      Rails.logger.info "Successfully updated location address to #{country_code}"
    end
  rescue => e
    Rails.logger.warn "Exception updating location address: #{e.message}"
    # Don't fail the whole registration if address update fails
  end

  def create_mutation
    <<~GRAPHQL
      mutation fulfillmentServiceCreate($name: String!, $callbackUrl: URL!, $trackingSupport: Boolean, $inventoryManagement: Boolean) {
        fulfillmentServiceCreate(
          name: $name,
          callbackUrl: $callbackUrl,
          trackingSupport: $trackingSupport,
          inventoryManagement: $inventoryManagement
        ) {
          fulfillmentService {
            id
            serviceName
            handle
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

  def create_variables
    {
      name: FULFILLMENT_SERVICE_NAME,
      callbackUrl: callback_url,
      trackingSupport: true,           # We provide tracking info when fulfilling
      inventoryManagement: false        # Print-on-demand = infinite stock, no need to report levels
    }
  end

  def delete_mutation
    <<~GRAPHQL
      mutation fulfillmentServiceDelete($id: ID!) {
        fulfillmentServiceDelete(id: $id) {
          deletedId
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end
end
