class SyncShopifyInventoryLocationJob < ApplicationJob
  queue_as :default
  self.enqueue_after_transaction_commit = true
  retry_on StandardError, wait: :polynomially_longer, attempts: 10

  def perform(variant_id, enabled, operation_key)
    Shopify::Lock.with(:inventory, variant_id) do
      variant = ProductVariant.find_by(id: variant_id)
      return unless variant && variant.product.store.active?
      return unless variant.metadata["inventory_operation_key"] == operation_key
      return unless variant.fulfilment_active? == enabled

      service = InventoryActivationService.new(variant)
      result = if enabled
        service.activate_at_fulfillment_location!(idempotency_key: operation_key)
      else
        service.deactivate_from_fulfillment_location!
      end
      raise Shopify::Response::Error, result[:error] unless result[:success]
    end
  end
end
