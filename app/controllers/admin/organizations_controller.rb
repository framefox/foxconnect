class Admin::OrganizationsController < Admin::ApplicationController
  before_action :set_organization, only: [ :show, :edit, :update, :destroy ]

  def index
    @pagy, @organizations = pagy(Organization.includes(:users, :stores).order(:name))
  end

  def show
    @users = @organization.users.order(:email)
    @stores = @organization.stores.order(:name)
  end

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      redirect_to admin_organization_path(@organization), notice: "Organization created successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @organization.update(organization_params)
      redirect_to admin_organization_path(@organization), notice: "Organization updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @organization.users.any? || @organization.stores.any?
      redirect_to admin_organization_path(@organization), alert: "Cannot delete organization with users or stores. Reassign them first."
    else
      @organization.destroy
      redirect_to admin_organizations_path, notice: "Organization deleted successfully."
    end
  end

  private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name)
  end
end
