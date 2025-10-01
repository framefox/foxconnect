require "net/http"
require "uri"
require "json"

class OrderProductionService
  attr_reader :order

  def initialize(order:)
    @order = order
  end

  def call
    Rails.logger.info "Sending order #{order.display_name} (ID: #{order.id}) to production system"

    # Validate that order has items with variant mappings
    unless order_has_valid_items?
      return { success: false, error: "Order has no items with variant mappings configured" }
    end

    # Build the payload
    begin
      payload = build_production_payload
      Rails.logger.info "Payload built successfully - contains #{payload.dig(:draft_order, :draft_order_items)&.count || 0} items"
    rescue => e
      Rails.logger.error "Error building production payload: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      return { success: false, error: "Error preparing order data: #{e.message}" }
    end

    # Send to production API
    send_to_production_api(payload)
  end

  private

  def order_has_valid_items?
    eligible_items.any?
  end

  def eligible_items
    @eligible_items ||= order.active_order_items.includes(:variant_mapping).where.not(variant_mappings: { id: nil })
  end

  def build_production_payload
    Rails.logger.info "Building payload for #{eligible_items.count} eligible items"

    draft_order_items = eligible_items.map.with_index do |order_item, index|
      Rails.logger.info "Processing order item #{index + 1}: #{order_item.id}"

      begin
        variant_mapping = order_item.variant_mapping
        unless variant_mapping
          Rails.logger.error "No variant mapping found for order item #{order_item.id}"
          next
        end

        Rails.logger.info "Variant mapping found: #{variant_mapping.id}"

        # Use read_attribute to avoid any potential method calls that might cause issues
        mapping_id = variant_mapping.read_attribute(:id)
        image_id = variant_mapping.read_attribute(:image_id)
        frame_sku_id = variant_mapping.read_attribute(:frame_sku_id)
        cx = variant_mapping.read_attribute(:cx)
        cy = variant_mapping.read_attribute(:cy)
        cw = variant_mapping.read_attribute(:cw)
        ch = variant_mapping.read_attribute(:ch)

        Rails.logger.info "Extracted values - mapping_id: #{mapping_id}, image_id: #{image_id}, frame_sku_id: #{frame_sku_id}, cx: #{cx}, cy: #{cy}, cw: #{cw}, ch: #{ch}"

        {
          variant_mapping_id: mapping_id,
          image_id: image_id,
          frame_sku_id: frame_sku_id,
          cx: cx,
          cy: cy,
          cw: cw,
          ch: ch
        }
      rescue => e
        Rails.logger.error "Error processing order item #{order_item.id}: #{e.message}"
        Rails.logger.error e.backtrace.join("\n")
        raise e
      end
    end.compact

    Rails.logger.info "Successfully built draft_order_items array with #{draft_order_items.count} items"

    {
      draft_order: {
        draft_order_items: draft_order_items
      }
    }
  end

  def send_to_production_api(payload)
    uri = URI.parse(production_api_url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 10 # seconds
    http.read_timeout = 30 # seconds

    request = Net::HTTP::Post.new(uri.request_uri)
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    # Convert to JSON with error handling
    begin
      json_payload = payload.to_json
      request.body = json_payload
      Rails.logger.info "Sending payload to #{production_api_url}: #{json_payload}"
    rescue => e
      Rails.logger.error "Error converting payload to JSON: #{e.message}"
      Rails.logger.error "Payload: #{payload.inspect}"
      Rails.logger.error e.backtrace.join("\n")
      raise e
    end

    begin
      response = http.request(request)

      Rails.logger.info "Production API response: #{response.code} #{response.message}"
      Rails.logger.info "Response body: #{response.body}" if response.body.present?

      case response.code.to_i
      when 200, 201, 202
        # Success responses
        {
          success: true,
          response: parse_response_body(response.body),
          status_code: response.code.to_i
        }
      when 400
        # Bad request
        error_message = extract_error_message(response.body) || "Bad request - check order data"
        Rails.logger.error "Production API bad request (400): #{error_message}"
        { success: false, error: error_message }
      when 401
        # Unauthorized
        Rails.logger.error "Production API unauthorized (401)"
        { success: false, error: "Authentication failed with production system" }
      when 404
        # Not found
        Rails.logger.error "Production API endpoint not found (404)"
        { success: false, error: "Production API endpoint not available" }
      when 422
        # Unprocessable entity
        error_message = extract_error_message(response.body) || "Invalid data sent to production system"
        Rails.logger.error "Production API validation error (422): #{error_message}"
        { success: false, error: error_message }
      when 500, 502, 503, 504
        # Server errors
        Rails.logger.error "Production API server error (#{response.code}): #{response.message}"
        { success: false, error: "Production system is currently unavailable" }
      else
        # Other errors
        Rails.logger.error "Production API unexpected response (#{response.code}): #{response.message}"
        { success: false, error: "Unexpected response from production system" }
      end

    rescue Net::TimeoutError => e
      Rails.logger.error "Production API timeout: #{e.message}"
      { success: false, error: "Request to production system timed out" }
    rescue Net::HTTPError => e
      Rails.logger.error "Production API HTTP error: #{e.message}"
      { success: false, error: "Connection error with production system" }
    rescue StandardError => e
      Rails.logger.error "Production API unexpected error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      { success: false, error: "Unexpected error communicating with production system" }
    end
  end

  def production_api_url
    # You might want to make this configurable via environment variables
    ENV["PRODUCTION_API_URL"] || "http://dev.framefox.co.nz:3001/api/draft_orders"
  end

  def parse_response_body(body)
    return nil if body.blank?

    begin
      JSON.parse(body)
    rescue JSON::ParserError => e
      Rails.logger.warn "Failed to parse production API response as JSON: #{e.message}"
      body
    end
  end

  def extract_error_message(body)
    return nil if body.blank?

    begin
      parsed = JSON.parse(body)

      # Try common error message patterns
      error_message = parsed.dig("error") ||
                     parsed.dig("errors") ||
                     parsed.dig("message") ||
                     parsed.dig("error_message")

      if error_message.is_a?(Array)
        error_message.join(", ")
      elsif error_message.is_a?(Hash)
        error_message.values.flatten.join(", ")
      else
        error_message&.to_s
      end
    rescue JSON::ParserError
      # If we can't parse as JSON, return the raw body if it's not too long
      body.length > 200 ? "Invalid response format" : body
    end
  end
end
