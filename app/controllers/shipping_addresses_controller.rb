class ShippingAddressesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_order
  before_action :ensure_draft_order
  before_action :set_shipping_address, only: [ :edit, :update ]

  def new
    @shipping_address = @order.build_shipping_address
  end

  def edit
    # @shipping_address is set by before_action
  end

  def create
    @shipping_address = @order.build_shipping_address(shipping_address_params)
    
    # Set country from order if not provided
    @shipping_address.country = @order.country_name if @shipping_address.country.blank?
    @shipping_address.country_code = @order.country_code if @shipping_address.country_code.blank?

    if @shipping_address.save
      # Log activity
      @order.log_activity(
        activity_type: "shipping_address_added",
        title: "Shipping address added",
        description: "Shipping address added to #{@shipping_address.full_name}",
        actor: current_user
      )

      redirect_to order_path(@order), notice: "Shipping address added successfully."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    # Set country from order if not provided
    params[:shipping_address][:country] = @order.country_name if params[:shipping_address][:country].blank?
    params[:shipping_address][:country_code] = @order.country_code if params[:shipping_address][:country_code].blank?

    if @shipping_address.update(shipping_address_params)
      # Log activity
      @order.log_activity(
        activity_type: "shipping_address_updated",
        title: "Shipping address updated",
        description: "Shipping address updated for #{@shipping_address.full_name}",
        actor: current_user
      )

      redirect_to order_path(@order), notice: "Shipping address updated successfully."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_order
    # Find order by uid that belongs to current user's organization
    @order = Order.for_organization(current_user.organization_id)
                  .find_by!(uid: params[:order_id])
  end

  def set_shipping_address
    @shipping_address = @order.shipping_address
    
    unless @shipping_address
      redirect_to new_order_shipping_address_path(@order), alert: "No shipping address found for this order."
    end
  end

  def ensure_draft_order
    unless @order.draft?
      redirect_to order_path(@order), alert: "Shipping address can only be modified for draft orders."
    end
  end

  def shipping_address_params
    params.require(:shipping_address).permit(
      :first_name,
      :last_name,
      :name,
      :company,
      :phone,
      :address1,
      :address2,
      :city,
      :province,
      :province_code,
      :postal_code,
      :country,
      :country_code
    )
  end
end

