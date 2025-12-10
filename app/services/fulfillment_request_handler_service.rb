# Handles fulfillment requests and cancellation requests from merchants.
# Used when merchants click "Request fulfillment" or "Cancel fulfillment" in Shopify Admin.
#
# Usage:
#   service = FulfillmentRequestHandlerService.new(store)
#   service.accept_pending_requests!
#   service.accept_pending_cancellations!
#
class FulfillmentRequestHandlerService
  attr_reader :store, :session, :errors

  def initialize(store)
    @store = store
    @errors = []

    unless store.shopify?
      raise ArgumentError, "Fulfillment request handling is only supported for Shopify stores"
    end

    @session = ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  # Query and accept all pending fulfillment requests assigned to our fulfillment service
  def accept_pending_requests!
    Rails.logger.info "Accepting pending fulfillment requests for store: #{store.name}"

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # Query assigned fulfillment orders with FULFILLMENT_REQUESTED status
    response = client.query(
      query: assigned_fulfillment_orders_query,
      variables: { assignmentStatus: "FULFILLMENT_REQUESTED" }
    )

    fulfillment_orders = response.body.dig("data", "shop", "assignedFulfillmentOrders", "edges") || []
    accepted_count = 0

    fulfillment_orders.each do |edge|
      fulfillment_order = edge["node"]
      fulfillment_order_id = fulfillment_order["id"]

      # Check if order exists locally, import if not
      ensure_order_imported(fulfillment_order)

      result = accept_fulfillment_request(client, fulfillment_order_id)
      if result[:success]
        accepted_count += 1
        Rails.logger.info "Accepted fulfillment request: #{fulfillment_order_id}"
      else
        @errors << "Failed to accept #{fulfillment_order_id}: #{result[:error]}"
      end
    end

    {
      success: errors.empty?,
      accepted_count: accepted_count,
      errors: errors
    }
  rescue StandardError => e
    Rails.logger.error "Exception accepting fulfillment requests: #{e.message}"
    { success: false, accepted_count: 0, errors: [ e.message ] }
  end

  # Query and process all pending cancellation requests
  def accept_pending_cancellations!
    Rails.logger.info "Processing pending cancellation requests for store: #{store.name}"

    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # Query assigned fulfillment orders with CANCELLATION_REQUESTED status
    response = client.query(
      query: assigned_fulfillment_orders_query,
      variables: { assignmentStatus: "CANCELLATION_REQUESTED" }
    )

    fulfillment_orders = response.body.dig("data", "shop", "assignedFulfillmentOrders", "edges") || []
    accepted_count = 0
    rejected_count = 0

    fulfillment_orders.each do |edge|
      fulfillment_order = edge["node"]
      fulfillment_order_id = fulfillment_order["id"]

      # Check if the order is already in production (can't cancel)
      # Ensure order exists locally first
      local_order = ensure_order_imported(fulfillment_order)

      if local_order && local_order.in_production?
        # Reject cancellation - already in production
        result = reject_cancellation_request(client, fulfillment_order_id,
          "Order is already in production and cannot be cancelled.")
        if result[:success]
          rejected_count += 1
          Rails.logger.info "Rejected cancellation for in-production order: #{fulfillment_order_id}"
        end
      else
        # Accept cancellation
        result = accept_cancellation_request(client, fulfillment_order_id,
          "Cancellation accepted. Order will not be fulfilled.")
        if result[:success]
          accepted_count += 1
          Rails.logger.info "Accepted cancellation request: #{fulfillment_order_id}"

          # Update local order if exists
          local_order&.cancel! if local_order&.may_cancel?
        end
      end
    end

    {
      success: errors.empty?,
      accepted_count: accepted_count,
      rejected_count: rejected_count,
      errors: errors
    }
  rescue StandardError => e
    Rails.logger.error "Exception processing cancellation requests: #{e.message}"
    { success: false, accepted_count: 0, rejected_count: 0, errors: [ e.message ] }
  end

  private

  def accept_fulfillment_request(client, fulfillment_order_id)
    response = client.query(
      query: accept_fulfillment_request_mutation,
      variables: {
        id: fulfillment_order_id,
        message: "We're on it! Your order is being processed by Framefox."
      }
    )

    user_errors = response.body.dig("data", "fulfillmentOrderAcceptFulfillmentRequest", "userErrors") || []
    if user_errors.any?
      error_message = user_errors.map { |e| e["message"] }.join(", ")
      { success: false, error: error_message }
    else
      { success: true }
    end
  end

  def accept_cancellation_request(client, fulfillment_order_id, message)
    response = client.query(
      query: accept_cancellation_request_mutation,
      variables: { id: fulfillment_order_id, message: message }
    )

    user_errors = response.body.dig("data", "fulfillmentOrderAcceptCancellationRequest", "userErrors") || []
    if user_errors.any?
      error_message = user_errors.map { |e| e["message"] }.join(", ")
      @errors << error_message
      { success: false, error: error_message }
    else
      { success: true }
    end
  end

  def reject_cancellation_request(client, fulfillment_order_id, message)
    response = client.query(
      query: reject_cancellation_request_mutation,
      variables: { id: fulfillment_order_id, message: message }
    )

    user_errors = response.body.dig("data", "fulfillmentOrderRejectCancellationRequest", "userErrors") || []
    if user_errors.any?
      error_message = user_errors.map { |e| e["message"] }.join(", ")
      @errors << error_message
      { success: false, error: error_message }
    else
      { success: true }
    end
  end

  def find_local_order(fulfillment_order_data)
    # Try to find the local order by the Shopify order ID
    # The fulfillment order contains a reference to the original order
    order_id = fulfillment_order_data.dig("order", "id")
    return nil unless order_id

    # Extract numeric ID from GID
    numeric_id = order_id.split("/").last

    store.orders.find_by(external_id: numeric_id)
  end

  # Ensure the order exists in our local database
  # If not, import it from Shopify
  def ensure_order_imported(fulfillment_order_data)
    local_order = find_local_order(fulfillment_order_data)

    if local_order
      Rails.logger.info "Order already exists locally: #{local_order.display_name}"
      return local_order
    end

    # Order doesn't exist - import it
    order_gid = fulfillment_order_data.dig("order", "id")
    order_name = fulfillment_order_data.dig("order", "name")

    return nil unless order_gid

    # Extract numeric ID from GID
    order_id = order_gid.split("/").last

    Rails.logger.info "Order #{order_name} (#{order_id}) not found locally - importing from Shopify"

    begin
      service = ImportOrderService.new(store: store, order_id: order_id)
      imported_order = service.call

      if imported_order
        Rails.logger.info "Successfully imported order #{imported_order.display_name} from fulfillment request"
        imported_order
      else
        Rails.logger.warn "Failed to import order #{order_id} from Shopify"
        nil
      end
    rescue StandardError => e
      Rails.logger.error "Exception importing order #{order_id}: #{e.message}"
      @errors << "Failed to import order #{order_name}: #{e.message}"
      nil
    end
  end

  def assigned_fulfillment_orders_query
    <<~GRAPHQL
      query AssignedFulfillmentOrders($assignmentStatus: FulfillmentOrderAssignmentStatus!) {
        shop {
          assignedFulfillmentOrders(first: 50, assignmentStatus: $assignmentStatus) {
            edges {
              node {
                id
                status
                requestStatus
                order {
                  id
                  name
                }
                destination {
                  firstName
                  lastName
                }
                lineItems(first: 50) {
                  edges {
                    node {
                      id
                      productTitle
                      sku
                      remainingQuantity
                    }
                  }
                }
                merchantRequests(first: 5) {
                  edges {
                    node {
                      message
                    }
                  }
                }
              }
            }
          }
        }
      }
    GRAPHQL
  end

  def accept_fulfillment_request_mutation
    <<~GRAPHQL
      mutation AcceptFulfillmentRequest($id: ID!, $message: String) {
        fulfillmentOrderAcceptFulfillmentRequest(id: $id, message: $message) {
          fulfillmentOrder {
            id
            status
            requestStatus
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end

  def accept_cancellation_request_mutation
    <<~GRAPHQL
      mutation AcceptCancellationRequest($id: ID!, $message: String) {
        fulfillmentOrderAcceptCancellationRequest(id: $id, message: $message) {
          fulfillmentOrder {
            id
            status
            requestStatus
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end

  def reject_cancellation_request_mutation
    <<~GRAPHQL
      mutation RejectCancellationRequest($id: ID!, $message: String!) {
        fulfillmentOrderRejectCancellationRequest(id: $id, message: $message) {
          fulfillmentOrder {
            id
            status
            requestStatus
          }
          userErrors {
            field
            message
          }
        }
      }
    GRAPHQL
  end
end

