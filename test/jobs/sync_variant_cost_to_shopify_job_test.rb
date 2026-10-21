require "test_helper"
require "minitest/mock"

class SyncVariantCostToShopifyJobTest < ActiveJob::TestCase
  test "previously queued jobs do not load mappings or write Shopify costs" do
    unexpected_lookup = ->(*) { flunk "Disabled cost sync must not load a mapping" }

    VariantMapping.stub(:find_by, unexpected_lookup) do
      assert_nothing_raised do
        SyncVariantCostToShopifyJob.perform_now(123)
      end
    end
  end
end
