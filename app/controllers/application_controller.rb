class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include ToastNotifications

  # Include Pagy Backend for pagination
  include Pagy::Backend

  # Authentication helpers
  helper_method :current_customer, :customer_signed_in?

  def current_customer
    @current_customer ||= ShopifyCustomer.find_by(
      shopify_customer_id: session[:shopify_customer_id]
    ) if session[:shopify_customer_id]
  end

  def customer_signed_in?
    current_customer.present?
  end

  def authenticate_customer!
    unless customer_signed_in?
      redirect_to root_path, alert: "Please log in to continue"
    end
  end
end
