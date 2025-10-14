class Connections::ApplicationController < ApplicationController
  before_action :authenticate_customer!
  before_action :set_customer_for_store_creation
  after_action :clear_customer_from_thread

  protected

  def set_current_user
    # Use the customer authentication from ApplicationController
    @current_user = current_customer
  end

  def set_customer_for_store_creation
    # Store customer_id in thread for Store.store method to access
    # This stores the internal primary key ID, not the external Shopify ID
    Thread.current[:current_shopify_customer_id] = current_customer&.id
  end

  def clear_customer_from_thread
    Thread.current[:current_shopify_customer_id] = nil
  end
end
