class Admin::CompaniesController < Admin::ApplicationController
  before_action :set_company, only: [ :show, :edit, :update, :destroy ]

  def index
    @companies = Company.ordered_by_name.includes(:shopify_customers)
  end

  def show
    @shopify_customers = @company.shopify_customers.joins(:user).order("users.email")
  end

  def new
    @company = Company.new
  end

  def create
    @company = Company.new(company_params)

    if @company.save
      redirect_to admin_companies_path, notice: "Company created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @company.update(company_params)
      redirect_to admin_companies_path, notice: "Company updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @company.destroy
    redirect_to admin_companies_path, notice: "Company deleted successfully."
  end

  private

  def set_company
    @company = Company.find(params[:id])
  end

  def company_params
    params.require(:company).permit(
      :company_name,
      :shopify_company_id,
      :shopify_company_location_id,
      :shopify_company_contact_id
    )
  end
end
