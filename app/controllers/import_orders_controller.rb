class ImportOrdersController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_connected_stores, only: [ :new, :create ]

  def new
  end

  def create
    order_id = params[:order_id]
    store_id = params[:store_id]

    if order_id.blank? || store_id.blank?
      flash[:alert] = "Please provide both order ID and store selection."
      redirect_to new_import_order_path and return
    end

    # Ensure store belongs to current customer
    store = current_customer.stores.find(store_id)

    begin
      service = ImportOrderService.new(store: store, order_id: order_id)
      order = service.call

      if order
        flash[:notice] = "Order #{order.display_name} has been successfully imported."
        redirect_to order_path(order)
      else
        flash[:alert] = "Failed to import order. Please check the order ID and try again."
        redirect_to new_import_order_path
      end
    rescue StandardError => e
      Rails.logger.error "ImportOrderService failed: #{e.message}"
      flash[:alert] = "An error occurred while importing the order: #{e.message}"
      redirect_to new_import_order_path
    end
  end

  private

  def set_connected_stores
    # Only show customer's active stores
    @stores = current_customer.stores.where(active: true).order(:name)

    if @stores.empty?
      flash[:alert] = "No active stores connected. Please connect a store first."
      redirect_to connections_root_path
    end
  end
end
