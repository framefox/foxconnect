class Admin::ShopifyCustomersController < Admin::ApplicationController
  before_action :set_customer, only: [ :show, :edit, :update, :destroy, :create_company ]

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

  def quick_create
  end

  def perform_quick_create
    result = Admin::CustomerOnboardingService.new(
      external_shopify_id: params[:external_shopify_id],
      country_code: params[:country_code]
    ).call

    redirect_to admin_shopify_customer_path(result[:shopify_customer]),
      notice: "Successfully onboarded #{result[:user].full_name} (#{result[:company].company_name})"
  rescue Admin::CustomerOnboardingService::OnboardingError, StandardError => e
    Rails.logger.error "Quick onboarding failed: #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    redirect_to quick_create_admin_shopify_customers_path, alert: e.message
  end

  def create_company
    begin
      company = Shopify::CompanyCreationService.new(shopify_customer: @customer).call
      redirect_to admin_shopify_customer_path(@customer), notice: "Company '#{company.company_name}' created successfully"
    rescue StandardError => e
      Rails.logger.error "Failed to create company: #{e.message}"
      Rails.logger.error e.backtrace.first(5).join("\n")
      redirect_to admin_shopify_customer_path(@customer), alert: "Failed to create company: #{e.message}"
    end
  end

  private

  def set_customer
    @customer = ShopifyCustomer.find(params[:id])
  end

  def customer_params
    # email, first_name, last_name are now on User, not ShopifyCustomer
    params.require(:shopify_customer).permit(:external_shopify_id, :company_id, :user_id, :country_code)
  end
end
