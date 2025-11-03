class Admin::OrdersController < Admin::ApplicationController
  before_action :set_order, only: [ :show, :submit, :cancel_order, :reopen, :resync, :resend_email ]

  def index
    @orders = Order.includes(:store, :order_items, :shipping_address)
                   .order(created_at: :desc)

    # Filter by store if provided
    @orders = @orders.where(store_id: params[:store_id]) if params[:store_id].present?

    # Search by order number or customer name
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @orders = @orders.joins(:shipping_address)
                       .where("orders.name ILIKE ? OR orders.external_number ILIKE ? OR shipping_addresses.name ILIKE ? OR CONCAT(shipping_addresses.first_name, ' ', shipping_addresses.last_name) ILIKE ?",
                              search_term, search_term, search_term, search_term)
    end

    @pagy, @orders = pagy(@orders)

    # For filter dropdowns
    @stores = Store.order(:name)
  end

  def show
    @order_items = @order.active_order_items.includes(:product_variant, :variant_mapping)
    @removed_items = @order.order_items.deleted.includes(:product_variant, :variant_mapping)
  end

  def submit
    if @order.may_submit?

      # Send order to production system
      begin
        service = OrderProductionService.new(order: @order)
        production_result = service.call

        if production_result[:success]
          @order.submit!
          redirect_to admin_order_path(@order), notice: "Order submitted and successfully sent to production system."
        else
          error_message = production_result[:error] || "Unknown error occurred"
          Rails.logger.warn "Order #{@order.id} failed to send to production: #{error_message}"
          redirect_to admin_order_path(@order), alert: "Failed to send order to production: #{error_message}"
        end
      rescue => e
        Rails.logger.error "Order #{@order.id} production service failed: #{e.message}"
        redirect_to admin_order_path(@order), alert: "Production system communication failed: #{e.message}. Please try again or contact support."
      end
    else
      redirect_to admin_order_path(@order), alert: "Cannot submit order in current state."
    end
  end

  def cancel_order
    if @order.may_cancel?
      @order.cancel!
      redirect_to admin_order_path(@order), notice: "Order cancelled."
    else
      redirect_to admin_order_path(@order), alert: "Cannot cancel order in current state."
    end
  end

  def reopen
    if @order.may_reopen?
      @order.reopen!
      redirect_to admin_order_path(@order), notice: "Order reopened."
    else
      redirect_to admin_order_path(@order), alert: "Cannot reopen order in current state."
    end
  end

  def resync
    unless @order.draft?
      redirect_to admin_order_path(@order), alert: "Can only resync orders in Draft status."
      return
    end

    begin
      import_service = ImportOrderService.new(store: @order.store, order_id: @order.external_id)
      import_service.resync_order(@order)

      redirect_to admin_order_path(@order), notice: "Order successfully resynced from #{@order.store.platform.humanize}."
    rescue => e
      Rails.logger.error "Error resyncing order #{@order.id}: #{e.message}"
      redirect_to admin_order_path(@order), alert: "Failed to resync order: #{e.message}"
    end
  end

  def resend_email
    if @order.store.user.email.blank?
      redirect_to admin_order_path(@order), alert: "Cannot send email: No user email address on file."
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
          redirect_to admin_order_path(@order), alert: "Fulfillment ID required for fulfillment notification."
          return
        end
        OrderMailer.with(order_id: @order.id, fulfillment_id: fulfillment_id).fulfillment_notification.deliver_now
        email_description = "Fulfillment notification email"
      else
        redirect_to admin_order_path(@order), alert: "Unknown email type: #{email_type}"
        return
      end

      redirect_to admin_order_path(@order), notice: "#{email_description} resent to #{@order.store.user.email}."
    rescue => e
      Rails.logger.error "Error sending email for order #{@order.id}: #{e.message}"
      redirect_to admin_order_path(@order), alert: "Failed to send email: #{e.message}"
    end
  end

  private

  def set_order
    @order = Order.includes(:store, :order_items, :shipping_address,
                           fulfillments: { fulfillment_line_items: { order_item: [ :product_variant, :variant_mapping ] } },
                           order_items: [ :product_variant, :variant_mapping, :fulfillment_line_items ]).find_by!(uid: params[:id])
  end
end
