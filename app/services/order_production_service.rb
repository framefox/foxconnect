# Orchestrates the order production workflow by coordinating multiple services:
# - Production::ApiClient: Sends order to production API
# - Production::CostService: Saves metadata and costs
# - Shopify::DraftOrderService: Manages Shopify draft order completion
class OrderProductionService
  attr_reader :order

  def initialize(order:)
    @order = order
  end

  def call
    Rails.logger.info "Sending order #{order.display_name} to production"

    return failure("No items with variant mappings") unless valid_items?

    # Step 1: Send to production API
    api_result = Production::ApiClient.new(order: order).send_draft_order
    return api_result unless api_result[:success]

    # Step 2: Save metadata and get draft order GID
    draft_order_gid = save_production_metadata(api_result[:response])
    return failure("No draft order ID returned") unless draft_order_gid

    # Step 3: Complete the draft order in Shopify
    complete_draft_order(draft_order_gid)

    api_result
  rescue => e
    Rails.logger.error "Production service error: #{e.message}"
    failure("Unexpected error: #{e.message}")
  end

  private

  def valid_items?
    order.active_order_items.joins(:variant_mapping).any?
  end

  def save_production_metadata(api_response)
    cost_service = Production::CostService.new(order: order)
    cost_service.save_draft_order_metadata(api_response)
  end

  def complete_draft_order(draft_order_gid)
    draft_order_service = Shopify::DraftOrderService.new(
      order: order,
      draft_order_gid: draft_order_gid
    )
    draft_order_service.complete
  end

  def failure(message)
    Rails.logger.error "Production API error: #{message}"
    { success: false, error: message }
  end
end
