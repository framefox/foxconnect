class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [ :show, :submit, :submit_production, :cancel_order, :reopen, :resync, :sync_missing_products, :resend_email ]

  def index
    # All orders scoped to the current user's organization
    @orders = Order.for_organization(current_user.organization_id)
                   .includes(:store, :order_items, :shipping_address, :fulfillments)
                   .order(created_at: :desc)

    # Filter by status if provided
    if params[:status].present?
      case params[:status]
      when "partially_fulfilled"
        # Special case: in_production orders that are partially fulfilled
        # Filter to in_production, then narrow down in Ruby
        @orders = @orders.where(aasm_state: :in_production).to_a.select(&:partially_fulfilled?)
      else
        # Standard status filtering
        @orders = @orders.where(aasm_state: params[:status])
      end
    end

    # Search by order number or customer name
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @orders = @orders.left_outer_joins(:shipping_address)
                       .where("orders.name ILIKE ? OR orders.external_number ILIKE ? OR shipping_addresses.name ILIKE ? OR CONCAT(shipping_addresses.first_name, ' ', shipping_addresses.last_name) ILIKE ?",
                              search_term, search_term, search_term, search_term)
    end

    # Apply pagination (convert to array first if we did post-filtering for partially_fulfilled)
    if params[:status] == "partially_fulfilled"
      @pagy, @orders = pagy_array(@orders)
    else
      @pagy, @orders = pagy(@orders)
    end
  end

  def new
    @order = Order.new
  end

  def create
    # Generate unique external_id for manual orders
    external_id = generate_manual_external_id

    # Infer currency and country from user's country
    country_code = current_user.country
    currency = currency_for_country(country_code)

    # Create manual order (no store) with all required fields
    @order = Order.new(
      store_id: nil,  # Manual orders have no store
      user_id: current_user.id,  # Associate directly with user for audit trail
      organization_id: current_user.organization_id,  # Scope to organization
      external_id: external_id,
      name: order_params[:name],
      currency: currency,
      country_code: country_code,
      # Initialize all money fields to 0
      subtotal_price_cents: 0,
      total_discounts_cents: 0,
      total_shipping_cents: 0,
      total_tax_cents: 0,
      total_price_cents: 0,
      production_subtotal_cents: 0,
      production_shipping_cents: 0,
      production_total_cents: 0,
      # State defaults to draft via AASM
      processed_at: Time.current
    )

    if @order.save
      # Log activity for manual order creation
      @order.log_activity(
        activity_type: "order_created",
        title: "Manual order created",
        description: "Order manually created by #{current_user.full_name}",
        actor: current_user
      )

      redirect_to order_path(@order), notice: "Order created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
    @order_items = @order.active_order_items.includes(:product_variant, :variant_mapping).order(:id)
    @removed_items = @order.order_items.deleted.includes(:product_variant, :variant_mapping).order(:id)
  end

  def submit
    if @order.may_submit?

      # Send order to production system
      begin
        service = OrderProductionService.new(order: @order)
        production_result = service.call

        if production_result[:success]
          @order.submit!
          redirect_to order_path(@order), notice: "Order submitted and successfully sent to production system."
        else
          error_message = production_result[:error] || "Unknown error occurred"
          Rails.logger.warn "Order #{@order.id} failed to send to production: #{error_message}"
          redirect_to order_path(@order), alert: "Failed to send order to production: #{error_message}"
        end
      rescue => e
        Rails.logger.error "Order #{@order.id} production service failed: #{e.message}"
        redirect_to order_path(@order), alert: "Production system communication failed: #{e.message}. Please try again or contact support."
      end
    else
      redirect_to order_path(@order), alert: "Cannot submit order in current state."
    end
  end

  def submit_production
    unless @order.may_submit?
      render json: { success: false, error: "Cannot submit order in current state" }, status: :unprocessable_entity
      return
    end

    service = OrderProductionService.new(order: @order)
    result = service.call

    if result[:success]
      @order.submit!
      render json: { success: true, steps: result[:steps], redirect_url: order_path(@order) }
    else
      render json: { success: false, steps: result[:steps], error: result[:error], failed_step: result[:failed_step] }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Order #{@order.id} production service failed: #{e.message}"
    render json: { success: false, error: "Unexpected error: #{e.message}" }, status: :internal_server_error
  end

  def cancel_order
    if @order.may_cancel?
      @order.cancel!
      redirect_to order_path(@order), notice: "Order cancelled."
    else
      redirect_to order_path(@order), alert: "Cannot cancel order in current state."
    end
  end

  def reopen
    if @order.may_reopen?
      @order.reopen!
      redirect_to order_path(@order), notice: "Order reopened."
    else
      redirect_to order_path(@order), alert: "Cannot reopen order in current state."
    end
  end

  def resync
    # Only imported orders can be resynced
    if @order.manual_order?
      redirect_to order_path(@order), alert: "Manual orders cannot be resynced from a platform."
      return
    end

    unless @order.draft?
      redirect_to order_path(@order), alert: "Can only resync orders in Draft status."
      return
    end

    begin
      # Route to appropriate service based on platform
      import_service = case @order.store.platform
      when "shopify"
        ImportOrderService.new(store: @order.store, order_id: @order.external_id)
      when "squarespace"
        SquarespaceImportOrderService.new(store: @order.store, order_id: @order.external_id)
      else
        raise StandardError, "Order resync not supported for #{@order.store.platform} platform"
      end

      import_service.resync_order(@order)

      # Log the resync activity
      OrderActivityService.new(order: @order).log_order_resynced(actor: current_user)

      redirect_to order_path(@order), notice: "Order successfully resynced from #{@order.store.platform.humanize}."
    rescue => e
      Rails.logger.error "Error resyncing order #{@order.id}: #{e.message}"
      redirect_to order_path(@order), alert: "Failed to resync order: #{e.message}"
    end
  end

  def sync_missing_products
    # Only imported orders can sync products from platform
    if @order.manual_order?
      redirect_to order_path(@order), alert: "Manual orders cannot sync products from a platform."
      return
    end

    # Get unique external product IDs from order items with no product_variant
    unknown_items = @order.active_order_items.where(product_variant_id: nil)

    if unknown_items.none?
      redirect_to order_path(@order), notice: "No missing products to sync."
      return
    end

    product_ids = unknown_items.pluck(:external_product_id).compact.uniq

    if product_ids.none?
      redirect_to order_path(@order), alert: "Order items are missing external product IDs. Cannot sync."
      return
    end

    begin
      # Sync specific products synchronously
      service = ShopifyProductSyncService.new(@order.store)
      result = service.sync_specific_products(product_ids)

      # Resync the order to link the new products to order items
      import_service = ImportOrderService.new(store: @order.store, order_id: @order.external_id)
      import_service.resync_order(@order)

      redirect_to order_path(@order),
                  notice: "Successfully synced #{result[:products_synced]} #{'product'.pluralize(result[:products_synced])} and #{result[:variants_synced]} #{'variant'.pluralize(result[:variants_synced])}. Order updated."
    rescue => e
      Rails.logger.error "Error syncing missing products for order #{@order.id}: #{e.message}"
      redirect_to order_path(@order), alert: "Failed to sync products: #{e.message}"
    end
  end

  def resend_email
    if @order.owner_email.blank?
      redirect_to order_path(@order), alert: "Cannot send email: No user email address on file."
      return
    end

    # Get email type from params or default to draft_imported
    email_type = params[:email_type] || "draft_imported"

    # Get fulfillment_id if needed for fulfillment notifications
    fulfillment_id = params[:fulfillment_id]

    begin
      case email_type
      when "draft_imported"
        OrderMailer.with(order_id: @order.id).draft_imported.deliver_now
        email_description = "Draft imported email"
      when "fulfillment_notification"
        if fulfillment_id.blank?
          redirect_to order_path(@order), alert: "Fulfillment ID required for fulfillment notification."
          return
        end
        OrderMailer.with(order_id: @order.id, fulfillment_id: fulfillment_id).fulfillment_notification.deliver_now
        email_description = "Fulfillment notification email"
      else
        redirect_to order_path(@order), alert: "Unknown email type: #{email_type}"
        return
      end

      redirect_to order_path(@order), notice: "#{email_description} resent to #{@order.owner_email}."
    rescue => e
      Rails.logger.error "Error sending email for order #{@order.id}: #{e.message}"
      redirect_to order_path(@order), alert: "Failed to send email: #{e.message}"
    end
  end

  private

  def set_order
    # Find order by uid that belongs to current user's organization
    @order = Order.for_organization(current_user.organization_id)
                  .includes(:store, :order_items, :shipping_address,
                           fulfillments: { fulfillment_line_items: { order_item: [ :product_variant, :variant_mapping ] } },
                           order_items: [ :product_variant, :variant_mapping, :fulfillment_line_items ])
                  .find_by!(uid: params[:id])
  end

  def generate_manual_external_id
    # Format: MANUAL-{unix_timestamp}-{6_char_random}
    timestamp = Time.current.to_i
    random_suffix = SecureRandom.alphanumeric(6).upcase

    # Ensure global uniqueness for manual orders (store_id IS NULL)
    loop do
      external_id = "MANUAL-#{timestamp}-#{random_suffix}"
      break external_id unless Order.where(store_id: nil, external_id: external_id).exists?

      # If collision (unlikely), generate new random suffix
      random_suffix = SecureRandom.alphanumeric(6).upcase
    end
  end

  def currency_for_country(country_code)
    case country_code&.upcase
    when "AU"
      "AUD"
    when "NZ"
      "NZD"
    else
      "NZD" # Default to NZD if country not set or unsupported
    end
  end

  def order_params
    params.require(:order).permit(:name)
  end
end
