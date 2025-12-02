class OutboundSquarespaceFulfillmentService
  attr_reader :fulfillment, :order, :store, :errors

  def initialize(fulfillment:)
    @fulfillment = fulfillment
    @order = fulfillment.order
    @store = order.store
    @errors = []
  end

  def sync_to_squarespace
    # Skip manual orders (no store to sync to)
    if order.manual_order?
      Rails.logger.info "Skipping fulfillment sync - manual order (no connected store)"
      return { success: false, message: "Manual order - no platform sync" }
    end
    
    # Only sync Squarespace orders
    return { success: false, message: "Not a Squarespace order" } unless store.platform == "squarespace"
    return { success: false, message: "Missing external order ID" } unless order.external_id.present?

    # Block sync for inactive stores
    unless store.active?
      Rails.logger.warn "Attempted to sync fulfillment for inactive store: #{store.name}"
      return { success: false, message: "Store is inactive" }
    end

    begin
      # Build fulfillment payload
      payload = build_fulfillment_payload

      # Create API service
      api_service = SquarespaceApiService.new(
        access_token: store.squarespace_token,
        store: store
      )

      # Send fulfillment to Squarespace
      # Note: Squarespace API returns no data on successful fulfillment (204 No Content)
      api_service.fulfill_order(order.external_id, payload)

      Rails.logger.info "Successfully synced fulfillment #{fulfillment.id} to Squarespace order #{order.external_id}"
      log_success_activity
      { success: true }
    rescue SquarespaceApiService::SquarespaceApiError => e
      Rails.logger.error "OutboundSquarespaceFulfillmentService error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      log_error_activity(e.message)
      { success: false, error: e.message }
    rescue StandardError => e
      Rails.logger.error "OutboundSquarespaceFulfillmentService error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      log_error_activity(e.message)
      { success: false, error: e.message }
    end
  end

  private

  def build_fulfillment_payload
    # Build shipment data
    shipment = {}

    # Add ship date (use fulfilled_at or current time)
    # Squarespace requires UTC ISO-8601 format
    shipment[:shipDate] = (fulfillment.fulfilled_at || Time.current).utc.iso8601

    # Add shipping service (required by Squarespace)
    # Use carrier name as service, or default to "Standard Shipping"
    shipment[:service] = fulfillment.tracking_company.presence || "Standard Shipping"

    # Add tracking information if available
    shipment[:carrierName] = fulfillment.tracking_company if fulfillment.tracking_company.present?
    shipment[:trackingNumber] = fulfillment.tracking_number if fulfillment.tracking_number.present?
    shipment[:trackingUrl] = fulfillment.tracking_url if fulfillment.tracking_url.present?

    # Build the full payload
    {
      shouldSendNotification: true,  # Send tracking email to customer
      shipments: [ shipment.compact ]
    }
  end

  def log_success_activity
    OrderActivityService.new(order: order).log_squarespace_fulfillment_synced(
      fulfillment: fulfillment
    )
  end

  def log_error_activity(error_message)
    OrderActivityService.new(order: order).log_squarespace_fulfillment_sync_failed(
      fulfillment: fulfillment,
      error: error_message
    )
  end
end
