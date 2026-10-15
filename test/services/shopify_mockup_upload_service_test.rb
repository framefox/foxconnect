require "test_helper"

class ShopifyMockupUploadServiceTest < ActiveSupport::TestCase
  class Client
    attr_reader :variables
    attr_accessor :errors

    def query(query:, variables:)
      @variables = variables
      Struct.new(:body).new({ "data" => { "stagedUploadsCreate" => {
        "userErrors" => errors || [],
        "stagedTargets" => [ { "url" => "https://uploads.example.com/upload", "resourceUrl" => "https://uploads.example.com/mockup.jpg", "parameters" => [ { "name" => "key", "value" => "target-key" } ] } ]
      } } })
    end
  end

  class Upload < ShopifyMockupUploadService
    attr_reader :requests
    attr_accessor :download_status, :upload_status, :mime, :bytes

    def initialize(client)
      super
      @requests = []
      @bytes = "\xFF\xD8mockup".b
    end

    private

    def perform_request(uri, request)
      @requests << request
      if request.is_a?(Net::HTTP::Get)
        response = Net::HTTPResponse::CODE_TO_OBJ.fetch(download_status || "200").new("1.1", download_status || "200", "Test")
        response["content-type"] = mime || "image/jpeg"
        data = bytes
        response.define_singleton_method(:read_body) { |&block| block.call(data) }
        yield response
      else
        # Read the multipart file while the tempfile is still open.
        @uploaded_bytes = request.instance_variable_get(:@body_data).last[1].read
        Net::HTTPResponse::CODE_TO_OBJ.fetch(upload_status || "201").new("1.1", upload_status || "201", "Test")
      end
    end
  end

  test "long renderer URL is downloaded and staged with a short explicit filename" do
    client = Client.new
    service = Upload.new(client)
    url = "https://res.cloudinary.com/framefox/image/fetch/preview.jpg%3Fartwork%3D#{'a' * 600}"
    assert_equal "https://uploads.example.com/mockup.jpg", service.upload(url)
    input = client.variables.fetch("input").first
    assert_match(/\Aframefox-mockup-[a-f0-9]{24}\.jpg\z/, input["filename"])
    assert_equal "image/jpeg", input["mimeType"]
    assert_equal "POST", input["httpMethod"]
    assert_equal service.bytes.bytesize.to_s, input["fileSize"]
    assert_equal service.bytes, service.instance_variable_get(:@uploaded_bytes)
    file = service.requests.last.instance_variable_get(:@body_data).last[1]
    assert file.closed?
  end

  test "download errors and non-image responses never create a Shopify upload" do
    [ [ "404", "image/jpeg" ], [ "200", "text/html" ] ].each do |status, mime|
      client = Client.new
      service = Upload.new(client)
      service.download_status = status
      service.mime = mime
      assert_raises(RuntimeError) { service.upload("https://example.com/image") }
      assert_nil client.variables
    end
  end

  test "Shopify staging errors stop before the multipart upload" do
    client = Client.new
    client.errors = [ { "message" => "Access denied" } ]
    service = Upload.new(client)
    assert_equal "Access denied", assert_raises(RuntimeError) { service.upload("https://example.com/image") }.message
    assert_equal 1, service.requests.size
  end

  test "failed multipart upload never returns a source URL" do
    service = Upload.new(Client.new)
    service.upload_status = "403"
    assert_match(/HTTP 403/, assert_raises(RuntimeError) { service.upload("https://example.com/image") }.message)
  end
end
