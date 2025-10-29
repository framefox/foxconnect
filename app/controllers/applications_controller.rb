class ApplicationsController < ApplicationController
  layout "devise"

  def new
    # Show application form
    # No authentication required - public page
  end

  def create
    @params = application_params

    # Validate required fields
    if @params[:name].blank? || @params[:email].blank? || @params[:country].blank?
      flash[:alert] = "Please fill in all required fields"
      render :new and return
    end

    # Send email based on country
    ApplicationSubmissionMailer.new_application(@params).deliver_now

    redirect_to root_path, notice: "Thank you for your application! We'll be in touch soon."
  end

  private

  def application_params
    params.require(:application).permit(
      :name,
      :email,
      :country,
      :country_other,
      :website_url,
      :website_platform,
      :website_platform_other,
      :already_selling,
      :order_volume
    )
  end
end

