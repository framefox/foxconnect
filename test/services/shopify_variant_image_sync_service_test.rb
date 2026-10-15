require "test_helper"
require "minitest/mock"

class ShopifyVariantImageSyncServiceTest < ActiveSupport::TestCase
  class Service < ShopifyVariantImageSyncService
    attr_reader :events
    attr_accessor :ready, :upload_success, :association_success

    def initialize
      @events = []
      @ready = @upload_success = @association_success = true
    end

    def graphql_client; nil; end
    def find_existing_variant_media(*)
      { "id" => "old-media" }
    end
    def add_media_to_product(_product, source, _alt)
      @events << [ :create, source ]
      { success: upload_success, media_id: "new-media", error: "Upload failed" }
    end
    def wait_for_media_ready(*)
      @events << :wait
      ready
    end
    def detach_variant_media(*)
      @events << :detach
      { success: true }
    end
    def associate_media_to_variant(_product, _variant, media)
      @events << [ :associate, media ]
      { success: media == "old-media" || association_success, error: "Association failed" }
    end
  end

  def sync(service)
    uploader = Object.new
    uploader.define_singleton_method(:upload) { |_| "https://staged.example.com/mockup.jpg" }
    ShopifyMockupUploadService.stub(:new, uploader) do
      service.sync_variant_image(shopify_product_id: 1, shopify_variant_id: 2, image_url: "https://example.com/long-url")
    end
  end

  test "staged media is ready before detaching the existing image" do
    service = Service.new
    assert sync(service)[:success]
    assert_equal [ [ :create, "https://staged.example.com/mockup.jpg" ], :wait, :detach, [ :associate, "new-media" ] ], service.events
  end

  test "failed upload or processing preserves the existing variant image" do
    [ :upload_success, :ready ].each do |attribute|
      service = Service.new
      service.public_send("#{attribute}=", false)
      assert_not sync(service)[:success]
      assert_not_includes service.events, :detach
    end
  end

  test "failed replacement association restores the old image" do
    service = Service.new
    service.association_success = false
    assert_not sync(service)[:success]
    assert_equal [ :associate, "old-media" ], service.events.last
  end
end
