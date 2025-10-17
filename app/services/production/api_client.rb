require "http"

module Production
  class ApiClient
    attr_reader :order

    def initialize(order:)
      @order = order
    end

    def send_draft_order
      Rails.logger.info "Sending order #{order.display_name} to production"

      return failure("No items with variant mappings") unless valid_items.any?

      payload = build_payload
      send_to_api(payload)
    rescue => e
      Rails.logger.error "Production service error: #{e.message}"
      failure("Unexpected error: #{e.message}")
    end

    private

    def valid_items
      @valid_items ||= order.fulfillable_items.joins(:variant_mapping)
    end

    def build_payload
      draft_order_items = valid_items.map do |item|
        mapping = item.variant_mapping
        {
          variant_mapping_id: mapping.id,
          image_id: mapping.image_id,
          frame_sku_id: mapping.frame_sku_id,
          cx: mapping.cx,
          cy: mapping.cy,
          cw: mapping.cw,
          ch: mapping.ch,
          width: mapping.width,
          height: mapping.height,
          unit: mapping.unit
        }
      end

      { draft_order: { draft_order_items: draft_order_items } }
    end

    def send_to_api(payload)
      response = HTTP
        .timeout(connect: 10, read: 30)
        .headers("Content-Type" => "application/json", "Accept" => "application/json")
        .post(api_url, json: payload)

      handle_response(response)
    rescue HTTP::TimeoutError
      failure("Request timed out")
    rescue HTTP::ConnectionError
      failure("Connection error")
    end

    def handle_response(response)
      case response.status
      when 200..202
        data = JSON.parse(response.body.to_s)
        success(data)
      when 400..499
        error_message = extract_error_message(response)
        failure("Client error (#{response.status}): #{error_message}")
      when 500..599
        error_message = extract_error_message(response)
        failure("Server error (#{response.status}): #{error_message}")
      else
        error_message = extract_error_message(response)
        failure("Unexpected response (#{response.status}): #{error_message}")
      end
    rescue JSON::ParserError
      failure("Invalid response format")
    end

    def api_url
      return ENV["PRODUCTION_API_URL"] || "http://dev.framefox.co.nz:3001/api/draft_orders" unless order.country_config
      "#{order.country_config['api_url']}#{order.country_config['api_base_path']}/draft_orders"
    end

    def success(data)
      { success: true, response: data }
    end

    def failure(message)
      Rails.logger.error "Production API error: #{message}"
      { success: false, error: message }
    end

    def extract_error_message(response)
      return "Unknown error" if response.body.to_s.empty?

      begin
        error_data = JSON.parse(response.body.to_s)

        # Try different common error message formats
        if error_data.is_a?(Hash)
          # Check for common error message keys
          error_message = error_data["error"] ||
                         error_data["message"] ||
                         error_data["errors"]&.join(", ") ||
                         error_data.dig("errors", "message") ||
                         error_data.dig("error", "message")

          return error_message if error_message.present?
        end

        # If no structured error found, return the raw body (truncated if too long)
        raw_body = response.body.to_s
        raw_body.length > 200 ? "#{raw_body[0..200]}..." : raw_body
      rescue JSON::ParserError
        # If response isn't JSON, return raw body (truncated if too long)
        raw_body = response.body.to_s
        raw_body.length > 200 ? "#{raw_body[0..200]}..." : raw_body
      end
    end
  end
end
