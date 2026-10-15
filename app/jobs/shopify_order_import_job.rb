class ShopifyOrderImportJob < ShopifyWebhookJob
  def perform(store_id, order_id, webhook_log_id)
    process_delivery(webhook_log_id) do
      store = Store.find_by(id: store_id)
      next unless store&.active? && !store.order_import_paused?
      # Different Shopify events can refer to the same order.
      Shopify::Lock.with(:store, store.id) do
        begin
          ImportOrderService.new(store: store, order_id: order_id).call
        rescue ImportOrderService::CountryBlocked => error
          # An intentional policy block is complete, not a transient API failure.
          WebhookLog.find(webhook_log_id).update!(error_message: "Blocked by country policy: #{error.message}")
        end
      end
    end
  end
end
