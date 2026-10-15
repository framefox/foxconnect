require "net/http"
require "tempfile"
require "digest"

# Stage image bytes with a short filename: Cloudinary fetch URLs encode an entire
# renderer URL in their path, which exceeds Shopify's inferred filename limit.
class ShopifyMockupUploadService
  MAX_BYTES = 20.megabytes
  EXTENSIONS = { "image/jpeg" => "jpg", "image/png" => "png", "image/webp" => "webp" }.freeze

  def initialize(client)
    @client = client
  end

  def upload(image_url)
    Tempfile.create([ "shopify-mockup", ".image" ]) do |file|
      file.binmode
      mime_type = download(image_url, file)
      extension = EXTENSIONS.fetch(mime_type) { raise "Unsupported mockup image type: #{mime_type}" }
      filename = "framefox-mockup-#{Digest::SHA256.file(file.path).hexdigest.first(24)}.#{extension}"
      target = create_target(filename, mime_type, file.size)
      file.rewind
      request = Net::HTTP::Post.new(URI(target.fetch("url")))
      fields = target.fetch("parameters").map { |parameter| [ parameter.fetch("name"), parameter.fetch("value") ] }
      fields << [ "file", file, { filename: filename, content_type: mime_type } ]
      request.set_form(fields, "multipart/form-data")
      response = perform_request(URI(target.fetch("url")), request)
      raise "Shopify staged upload failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)

      target.fetch("resourceUrl")
    end
  end

  private

  def download(url, file, redirects = 3)
    uri = URI(url)
    raise "Mockup source must use HTTPS" unless uri.is_a?(URI::HTTPS)

    mime_type = nil
    redirect = nil
    perform_request(uri, Net::HTTP::Get.new(uri)) do |response|
      if response.is_a?(Net::HTTPRedirection)
        raise "Too many mockup redirects" if redirects.zero?
        redirect = URI.join(url, response.fetch("location")).to_s
      else
        raise "Mockup download failed (HTTP #{response.code})" unless response.is_a?(Net::HTTPSuccess)
        mime_type = response["content-type"].to_s.split(";").first
        raise "Unsupported mockup image type: #{mime_type}" unless EXTENSIONS.key?(mime_type)
        response.read_body do |chunk|
          raise "Mockup exceeds 20 MB" if file.size + chunk.bytesize > MAX_BYTES
          file.write(chunk)
        end
      end
    end
    return download(redirect, file, redirects - 1) if redirect
    raise "Mockup download was empty" if file.size.zero?
    file.flush
    mime_type
  end

  def perform_request(uri, request, &block)
    raise "Upload URL must use HTTPS" unless uri.is_a?(URI::HTTPS)
    Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 15, read_timeout: 120, write_timeout: 120) do |http|
      http.request(request, &block)
    end
  end

  def create_target(filename, mime_type, size)
    query = <<~GRAPHQL
      mutation StageMockupUpload($input: [StagedUploadInput!]!) {
        stagedUploadsCreate(input: $input) {
          stagedTargets { url resourceUrl parameters { name value } }
          userErrors { field message }
        }
      }
    GRAPHQL
    response = @client.query(query: query, variables: {
      "input" => [ { "filename" => filename, "mimeType" => mime_type,
        "fileSize" => size.to_s, "httpMethod" => "POST", "resource" => "IMAGE" } ]
    }).body
    payload = response.dig("data", "stagedUploadsCreate")
    errors = Array(response["errors"]) + Array(payload&.dig("userErrors"))
    raise errors.map { |error| error["message"] }.join(", ") if errors.any?
    target = payload&.dig("stagedTargets")&.first
    raise "Shopify did not return a staged upload target" unless target && target["resourceUrl"].present?
    target
  end
end
