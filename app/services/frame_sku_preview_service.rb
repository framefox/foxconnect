require "net/http"

class FrameSkuPreviewService
  class Unavailable < StandardError; end

  def self.ensure_for(mapping)
    return unless mapping.image.present? && mapping.preview_url.blank?

    mapping.preview_url = call(frame_sku_id: mapping.frame_sku_id, country_code: mapping.country_code)
  end

  def self.call(frame_sku_id:, country_code:)
    config = CountryConfig.for_country(country_code)
    raise Unavailable, "Preview service is not configured for this country." unless config

    uri = URI("#{config.fetch('api_url')}#{config.fetch('api_base_path')}/frame_skus/batch.json")
    uri.query = URI.encode_www_form(frame_sku_ids: frame_sku_id)
    request = Net::HTTP::Get.new(uri)
    request["Authorization"] = "Bearer #{ENV['FRAMEFOX_API_KEY']}" if ENV["FRAMEFOX_API_KEY"].present?
    request["Accept"] = "application/json"
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 15) { |http| http.request(request) }
    raise Unavailable, "Could not load the product preview. Please try again." unless response.is_a?(Net::HTTPSuccess)

    sku = JSON.parse(response.body).fetch("frame_skus", []).find { |item| item["id"].to_s == frame_sku_id.to_s }
    preview = sku&.fetch("preview_image", nil)
    raise Unavailable, "This product's preview is unavailable. Please choose the product again." if preview.blank?

    preview
  rescue JSON::ParserError, IOError, SystemCallError, Timeout::Error, SocketError, OpenSSL::SSL::SSLError
    raise Unavailable, "Could not load the product preview. Please try again."
  end
end
