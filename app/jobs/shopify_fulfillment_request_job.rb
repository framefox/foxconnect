class ShopifyFulfillmentRequestJob < ShopifyWebhookJob
  def perform(store_id, kind, webhook_log_id)
    process_delivery(webhook_log_id) do
      store = Store.find_by(id: store_id)
      next unless store&.active?
      Shopify::Lock.with(:store, store.id) do
        service = FulfillmentRequestHandlerService.new(store)
        result = case kind
        when "FULFILLMENT_REQUEST" then service.accept_pending_requests!
        when "CANCELLATION_REQUEST" then service.accept_pending_cancellations!
        else raise ArgumentError, "Unknown fulfillment notification"
        end
        raise Shopify::Response::Error, result[:errors].join(", ") unless result[:success]
      end
    end
  end
end
