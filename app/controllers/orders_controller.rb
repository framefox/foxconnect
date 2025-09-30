class OrdersController < ApplicationController
  before_action :set_order, only: [ :show, :submit, :start_production, :cancel_order, :reopen ]

  def index
    @orders = Order.includes(:store, :order_items, :shipping_address)
                   .order(created_at: :desc)

    # Filter by status if provided
    @orders = @orders.where(financial_status: params[:financial_status]) if params[:financial_status].present?
    @orders = @orders.where(fulfillment_status: params[:fulfillment_status]) if params[:fulfillment_status].present?

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

    # For filter dropdowns
    @stores = Store.order(:name)
    @financial_statuses = Order.financial_statuses.keys
    @fulfillment_statuses = Order.fulfillment_statuses.keys
  end

  def show
    @order_items = @order.order_items.includes(:product_variant, :variant_mapping)
  end

  def submit
    if @order.may_submit?
      @order.submit!
      redirect_to @order, notice: "Order submitted for production."
    else
      redirect_to @order, alert: "Cannot submit order in current state."
    end
  end

  def start_production
    if @order.may_start_production?
      @order.start_production!
      redirect_to @order, notice: "Order production started."
    else
      redirect_to @order, alert: "Cannot start production in current state."
    end
  end

  def cancel_order
    if @order.may_cancel?
      @order.cancel!
      redirect_to @order, notice: "Order cancelled."
    else
      redirect_to @order, alert: "Cannot cancel order in current state."
    end
  end

  def reopen
    if @order.may_reopen?
      @order.reopen!
      redirect_to @order, notice: "Order reopened."
    else
      redirect_to @order, alert: "Cannot reopen order in current state."
    end
  end

  private

  def set_order
    @order = Order.includes(:store, :order_items, :shipping_address, order_items: [ :product_variant, :variant_mapping ]).find(params[:id])
  end
end
