class ShopifyProductRemovalJob < ApplicationJob
  queue_as :default

  def perform(store_id, external_id)
    store = Store.find_by(id: store_id)
    return if store.nil? || external_id.blank?

    product = store.products.find_by(external_id: external_id.to_s)
    unless product
      Rails.logger.info "Shopify product delete webhook for unknown product #{external_id} on store #{store.name}"
      return
    end

    result = product.archive_from_source!
    Rails.logger.info(
      "Archived Shopify product #{product.external_id} from delete webhook " \
      "(product_archived=#{result[:product_archived]}, variants_archived=#{result[:variants_archived]})"
    )
  end
end
