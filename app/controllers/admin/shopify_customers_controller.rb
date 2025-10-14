class Admin::ShopifyCustomersController < Admin::ApplicationController
  before_action :set_customer, only: [ :show, :edit, :update, :destroy, :impersonate ]

  def index
    @pagy, @customers = pagy(ShopifyCustomer.order(created_at: :desc))
  end

  def show
    @stores = @customer.stores
  end

  def impersonate
    # Store the admin session info to return later
    session[:admin_shopify_domain] = current_shopify_session&.shop
    session[:impersonating] = true
    session[:impersonated_customer_id] = @customer.id
    session[:shopify_customer_id] = @customer.external_shopify_id

    redirect_to connections_root_path, notice: "Now viewing as #{@customer.full_name}"
  end

  def stop_impersonating
    impersonated_customer_id = session[:impersonated_customer_id]

    # Clear impersonation session
    session[:shopify_customer_id] = nil
    session[:impersonating] = nil
    session[:impersonated_customer_id] = nil

    if impersonated_customer_id
      redirect_to admin_shopify_customer_path(impersonated_customer_id), notice: "Stopped impersonating customer"
    else
      redirect_to admin_shopify_customers_path, notice: "Stopped impersonating customer"
    end
  end

  def new
    @customer = ShopifyCustomer.new
  end

  def create
    @customer = ShopifyCustomer.new(customer_params)
    if @customer.save
      redirect_to admin_shopify_customer_path(@customer), notice: "Customer created successfully"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @customer.update(customer_params)
      redirect_to admin_shopify_customer_path(@customer), notice: "Customer updated successfully"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @customer.destroy
    redirect_to admin_shopify_customers_path, notice: "Customer deleted successfully"
  end

  private

  def set_customer
    @customer = ShopifyCustomer.find(params[:id])
  end

  def customer_params
    params.require(:shopify_customer).permit(:external_shopify_id, :first_name, :last_name, :email)
  end
end
