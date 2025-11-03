class InboundFulfillmentService
  attr_reader :order, :fulfillment_data, :errors

  def initialize(order:, fulfillment_data:)
    @order = order
    @fulfillment_data = fulfillment_data
    @errors = []
  end

  def create_fulfillment
    ActiveRecord::Base.transaction do
      fulfillment = build_fulfillment
      return nil unless fulfillment

      if fulfillment.save
        create_fulfillment_line_items(fulfillment)
        log_fulfillment_activity(fulfillment)
        update_order_state
        sync_to_shopify(fulfillment)
        send_fulfillment_notification(fulfillment)
        fulfillment
      else
        @errors = fulfillment.errors.full_messages
        nil
      end
    end
  rescue StandardError => e
    @errors << e.message
    Rails.logger.error "InboundFulfillmentService error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    nil
  end

  def update_fulfillment(fulfillment)
    ActiveRecord::Base.transaction do
      update_attributes = extract_update_attributes

      if fulfillment.update(update_attributes)
        log_fulfillment_update_activity(fulfillment)
        fulfillment
      else
        @errors = fulfillment.errors.full_messages
        nil
      end
    end
  rescue StandardError => e
    @errors << e.message
    Rails.logger.error "InboundFulfillmentService update error: #{e.message}"
    nil
  end

  private

  def build_fulfillment
    Fulfillment.new(
      order: order,
      shopify_fulfillment_id: fulfillment_data["id"]&.to_s,
      status: map_status(fulfillment_data["status"]),
      tracking_company: fulfillment_data["tracking_company"],
      tracking_number: fulfillment_data["tracking_number"],
      tracking_url: build_tracking_url(fulfillment_data),
      location_name: extract_location_name(fulfillment_data),
      shopify_location_id: fulfillment_data["location_id"]&.to_s,
      shipment_status: fulfillment_data["shipment_status"],
      fulfilled_at: parse_datetime(fulfillment_data["created_at"]) || Time.current
    )
  end

  def extract_update_attributes
    {
      status: map_status(fulfillment_data["status"]),
      tracking_company: fulfillment_data["tracking_company"],
      tracking_number: fulfillment_data["tracking_number"],
      tracking_url: build_tracking_url(fulfillment_data),
      shipment_status: fulfillment_data["shipment_status"]
    }.compact
  end

  def create_fulfillment_line_items(fulfillment)
    line_items = fulfillment_data["line_items"] || []

    line_items.each do |line_item_data|
      order_item = find_order_item_by_shopify_id(line_item_data["id"])

      if order_item
        FulfillmentLineItem.create!(
          fulfillment: fulfillment,
          order_item: order_item,
          quantity: line_item_data["quantity"] || 1
        )
      else
        Rails.logger.warn "Could not find order_item for Shopify line_item_id: #{line_item_data['id']}"
      end
    end
  end

  def find_order_item_by_shopify_id(shopify_line_item_id)
    return nil unless shopify_line_item_id

    # Try to find by shopify_remote_line_item_id
    order_item = order.order_items.find_by(shopify_remote_line_item_id: shopify_line_item_id.to_s)

    # Fallback to external_line_id if needed
    order_item ||= order.order_items.find_by(external_line_id: shopify_line_item_id.to_s)

    order_item
  end

  def build_tracking_url(data)
    # Prefer tracking_url if present
    return data["tracking_url"] if data["tracking_url"].present?

    # Build URL from tracking_urls array if present
    tracking_urls = data["tracking_urls"] || []
    tracking_urls.first if tracking_urls.any?
  end

  def extract_location_name(data)
    # Try to get location name from various possible fields
    data["location_name"] || data.dig("origin_address", "name")
  end

  def map_status(shopify_status)
    case shopify_status&.downcase
    when "success"
      "success"
    when "pending"
      "pending"
    when "cancelled", "canceled"
      "cancelled"
    when "error"
      "error"
    when "failure"
      "failure"
    else
      "pending"
    end
  end

  def parse_datetime(datetime_string)
    return nil unless datetime_string
    Time.zone.parse(datetime_string)
  rescue ArgumentError
    nil
  end

  def log_fulfillment_activity(fulfillment)
    OrderActivityService.new(order: order).log_fulfillment_created(fulfillment: fulfillment)
  end

  def log_fulfillment_update_activity(fulfillment)
    OrderActivityService.new(order: order).log_fulfillment_updated(fulfillment: fulfillment)
  end

  def update_order_state
    # Check if order is fully fulfilled and update state
    if order.fully_fulfilled? && order.may_fulfill?
      order.fulfill!
    end
  end

  def sync_to_shopify(fulfillment)
    return unless fulfillment.order.store.platform == "shopify"

    # Trigger outbound sync in background to not block inbound processing
    outbound_service = OutboundFulfillmentService.new(fulfillment: fulfillment)
    outbound_service.sync_to_shopify
  rescue StandardError => e
    Rails.logger.error "Outbound fulfillment sync failed: #{e.message}"
    # Don't fail the inbound fulfillment if outbound sync fails
  end

  def send_fulfillment_notification(fulfillment)
    return unless order.store.user.email.present?

    # Send email in background
    OrderMailer.with(order_id: order.id, fulfillment_id: fulfillment.id).fulfillment_notification.deliver_later
  rescue StandardError => e
    Rails.logger.error "Failed to send fulfillment notification email: #{e.message}"
    # Don't fail the fulfillment if email fails
  end
end
