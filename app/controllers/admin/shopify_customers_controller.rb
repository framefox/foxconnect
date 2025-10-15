class Admin::ShopifyCustomersController < Admin::ApplicationController
  before_action :set_customer, only: [ :show, :edit, :update, :destroy ]

  def index
    @pagy, @customers = pagy(ShopifyCustomer.includes(:company).order(created_at: :desc))
  end

  def show
    # Access stores through the user since ShopifyCustomer no longer has stores
    @stores = @customer.user.stores
    @user = @customer.user
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
    # email, first_name, last_name are now on User, not ShopifyCustomer
    params.require(:shopify_customer).permit(:external_shopify_id, :company_id, :user_id)
  end
end
