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

    steps = {
      step1: { name: "Sending order to production API", status: "pending" },
      step2: { name: "Saving production metadata and costs", status: "pending" },
      step3: { name: "Completing Shopify draft order", status: "pending" }
    }

    return failure("No items with variant mappings", steps, 0) unless valid_items?

    # Step 1: Send to production API
    api_result = Production::ApiClient.new(order: order).send_draft_order
    unless api_result[:success]
      steps[:step1][:status] = "error"
      return { success: false, steps: steps, error: api_result[:error], failed_step: 1 }
    end
    steps[:step1][:status] = "success"

    # Step 2: Save metadata and get draft order GID
    draft_order_gid = save_production_metadata(api_result[:response])
    unless draft_order_gid
      steps[:step2][:status] = "error"
      return { success: false, steps: steps, error: "No draft order ID returned", failed_step: 2 }
    end
    steps[:step2][:status] = "success"

    # Step 3: Complete the draft order in Shopify
    complete_draft_order(draft_order_gid)
    steps[:step3][:status] = "success"

    { success: true, steps: steps }
  rescue => e
    Rails.logger.error "Production service error: #{e.message}"
    # Mark the current step as failed
    current_step = steps.values.count { |s| s[:status] == "success" } + 1
    step_key = "step#{current_step}".to_sym
    steps[step_key][:status] = "error" if steps[step_key]
    { success: false, steps: steps, error: "Unexpected error: #{e.message}", failed_step: current_step }
  end

  private

  def valid_items?
    order.fulfillable_items.joins(:variant_mapping).any?
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

  def failure(message, steps = {}, failed_step = 0)
    Rails.logger.error "Production API error: #{message}"
    { success: false, error: message, steps: steps, failed_step: failed_step }
  end
end
