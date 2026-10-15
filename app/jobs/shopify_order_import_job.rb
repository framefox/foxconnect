class ShopifyOrderImportJob < ShopifyWebhookJob
  def perform(store_id, order_id, webhook_log_id)
    process_delivery(webhook_log_id) do
      store = Store.find_by(id: store_id)
      next unless store&.active? && !store.order_import_paused?
      # Different Shopify events can refer to the same order.
      Shopify::Lock.with(:store, store.id) do
        ImportOrderService.new(store: store, order_id: order_id).call
      end
    end
  end
end
