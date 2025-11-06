class FulfillmentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order

  def new
    @unfulfilled_items = @order.active_order_items
                               .includes(:product_variant, :variant_mapping)
                               .select { |item| item.unfulfilled_quantity > 0 && item.fulfillable? }

    if @unfulfilled_items.empty?
      redirect_to order_path(@order), alert: "No unfulfilled items to fulfill."
      return
    end

    # Initialize with full quantities selected
    @selected_quantities = @unfulfilled_items.each_with_object({}) do |item, hash|
      hash[item.id] = item.unfulfilled_quantity
    end
  end

  def create
    line_items_params = params[:fulfillment][:line_items] || {}

    # Filter out items with quantity 0 or nil
    selected_items = line_items_params.to_unsafe_h.select { |_id, qty| qty.to_i > 0 }

    if selected_items.empty?
      redirect_to new_order_fulfillment_path(@order), alert: "Please select at least one item to fulfill."
      return
    end

    # Validate quantities don't exceed unfulfilled quantities
    errors = []
    selected_items.each do |item_id, quantity|
      item = @order.order_items.find(item_id)
      if quantity.to_i > item.unfulfilled_quantity
        errors << "#{item.display_name}: cannot fulfill #{quantity} (only #{item.unfulfilled_quantity} remaining)"
      end
    end

    if errors.any?
      flash[:alert] = "Invalid quantities: #{errors.join(', ')}"
      redirect_to new_order_fulfillment_path(@order)
      return
    end

    # Extract tracking information from params
    tracking_company = params[:fulfillment][:tracking_company].presence
    tracking_number = params[:fulfillment][:tracking_number].presence
    tracking_url = params[:fulfillment][:tracking_url].presence

    # Create fulfillment
    fulfillment = Fulfillment.new(
      order: @order,
      status: "success",
      fulfilled_at: Time.current,
      tracking_company: tracking_company,
      tracking_number: tracking_number,
      tracking_url: tracking_url
    )

    ActiveRecord::Base.transaction do
      if fulfillment.save
        # Create fulfillment line items
        selected_items.each do |item_id, quantity|
          FulfillmentLineItem.create!(
            fulfillment: fulfillment,
            order_item_id: item_id,
            quantity: quantity.to_i
          )
        end

        # Update order state if fully fulfilled
        if @order.fully_fulfilled?
          @order.fulfill! if @order.may_fulfill?
        end

        # Log activity
        activity_metadata = {
          fulfillment_id: fulfillment.id,
          item_count: selected_items.size
        }
        activity_metadata[:tracking_company] = tracking_company if tracking_company
        activity_metadata[:tracking_number] = tracking_number if tracking_number
        activity_metadata[:tracking_url] = tracking_url if tracking_url

        @order.log_activity(
          activity_type: "fulfillment_created",
          title: "Fulfillment created",
          description: "#{selected_items.values.sum(&:to_i)} items marked as fulfilled",
          metadata: activity_metadata,
          actor: current_user
        )

        # Sync fulfillment to platform (Shopify or Squarespace)
        sync_fulfillment_to_platform(fulfillment)

        # Send fulfillment notification email
        if @order.store.user.email.present?
          OrderMailer.with(order_id: @order.id, fulfillment_id: fulfillment.id).fulfillment_notification.deliver_later
        end

        redirect_to order_path(@order), notice: "Fulfillment created successfully."
      else
        redirect_to new_order_fulfillment_path(@order), alert: "Failed to create fulfillment: #{fulfillment.errors.full_messages.join(', ')}"
      end
    end
  rescue => e
    Rails.logger.error "Error creating fulfillment: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    redirect_to new_order_fulfillment_path(@order), alert: "An error occurred: #{e.message}"
  end

  private

  def set_order
    # Ensure the order belongs to one of the user's stores
    @order = Order.joins(:store)
                  .where(stores: { user_id: current_user.id })
                  .includes(:store, order_items: [ :product_variant, :variant_mapping ])
                  .find_by!(uid: params[:order_id])
  end

  def sync_fulfillment_to_platform(fulfillment)
    case @order.store.platform
    when "shopify"
      sync_to_shopify(fulfillment)
    when "squarespace"
      sync_to_squarespace(fulfillment)
    end
  end

  def sync_to_shopify(fulfillment)
    outbound_service = OutboundFulfillmentService.new(fulfillment: fulfillment)
    result = outbound_service.sync_to_shopify

    if result[:success]
      Rails.logger.info "Manual fulfillment #{fulfillment.id} synced to Shopify"
    else
      Rails.logger.warn "Failed to sync manual fulfillment #{fulfillment.id} to Shopify: #{result[:error]}"
      # Don't block the user flow, just log the warning
    end
  rescue StandardError => e
    Rails.logger.error "Error syncing manual fulfillment to Shopify: #{e.message}"
    # Don't block the user flow if sync fails
  end

  def sync_to_squarespace(fulfillment)
    outbound_service = OutboundSquarespaceFulfillmentService.new(fulfillment: fulfillment)
    result = outbound_service.sync_to_squarespace

    if result[:success]
      Rails.logger.info "Manual fulfillment #{fulfillment.id} synced to Squarespace"
    else
      Rails.logger.warn "Failed to sync manual fulfillment #{fulfillment.id} to Squarespace: #{result[:error]}"
      # Don't block the user flow, just log the warning
    end
  rescue StandardError => e
    Rails.logger.error "Error syncing manual fulfillment to Squarespace: #{e.message}"
    # Don't block the user flow if sync fails
  end
end
