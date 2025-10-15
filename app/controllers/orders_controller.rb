class OrdersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order, only: [ :show, :submit, :cancel_order, :reopen, :resync, :resend_email ]

  def index
    # Scope to only orders from the current user's stores
    @orders = Order.joins(:store)
                   .where(stores: { user_id: current_user.id })
                   .includes(:store, :order_items, :shipping_address)
                   .order(created_at: :desc)

    # Filter by store if provided
    @orders = @orders.where(store_id: params[:store_id]) if params[:store_id].present?

    # Search by order number, customer email, or customer name
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @orders = @orders.joins(:shipping_address)
                       .where("orders.name ILIKE ? OR orders.external_number ILIKE ? OR orders.customer_email ILIKE ? OR shipping_addresses.name ILIKE ? OR CONCAT(shipping_addresses.first_name, ' ', shipping_addresses.last_name) ILIKE ?",
                              search_term, search_term, search_term, search_term, search_term)
    end

    @pagy, @orders = pagy(@orders)

    # For filter dropdowns - only user's stores
    @stores = current_user.stores.order(:name)
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
    begin
      import_service = ImportOrderService.new(store: @order.store, order_id: @order.external_id)
      import_service.resync_order(@order)

      redirect_to order_path(@order), notice: "Order successfully resynced from #{@order.store.platform.humanize}."
    rescue => e
      Rails.logger.error "Error resyncing order #{@order.id}: #{e.message}"
      redirect_to order_path(@order), alert: "Failed to resync order: #{e.message}"
    end
  end

  def resend_email
    if @order.customer_email.blank?
      redirect_to order_path(@order), alert: "Cannot send email: No customer email address on file."
      return
    end

    begin
      OrderMailer.with(order_id: @order.id).draft_imported.deliver_now
      redirect_to order_path(@order), notice: "Email confirmation sent to #{@order.customer_email}."
    rescue => e
      Rails.logger.error "Error sending email for order #{@order.id}: #{e.message}"
      redirect_to order_path(@order), alert: "Failed to send email: #{e.message}"
    end
  end

  private

  def set_order
    # Ensure the order belongs to one of the user's stores
    @order = Order.joins(:store)
                  .where(stores: { user_id: current_user.id })
                  .includes(:store, :order_items, :shipping_address,
                           fulfillments: { fulfillment_line_items: { order_item: [ :product_variant, :variant_mapping ] } },
                           order_items: [ :product_variant, :variant_mapping, :fulfillment_line_items ])
                  .find(params[:id])
  end
end
