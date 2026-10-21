# Retained so jobs queued before automatic cost write-back was disabled can drain safely.
# Shopify has one cost per inventory item, so regional costs must stay in FoxConnect.
class SyncVariantCostToShopifyJob < ApplicationJob
  queue_as :default

  def perform(variant_mapping_id)
    Rails.logger.info "Skipping disabled Shopify cost write-back for variant mapping #{variant_mapping_id}"
  end
end
