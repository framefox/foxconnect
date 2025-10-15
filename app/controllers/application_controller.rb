class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include ToastNotifications

  # Include Pagy Backend for pagination
  include Pagy::Backend

  # Authentication helpers
  helper_method :current_user, :user_signed_in?, :impersonating?, :impersonated_user
  # Backwards compatibility helpers
  helper_method :current_customer, :customer_signed_in?

  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end

  def user_signed_in?
    current_user.present?
  end

  def authenticate_user!
    unless user_signed_in?
      redirect_to root_path, alert: "Please log in to continue"
    end
  end

  def impersonating?
    session[:impersonating] == true
  end

  def impersonated_user
    return nil unless impersonating?
    @impersonated_user ||= User.find_by(id: session[:impersonated_user_id])
  end

  # Backwards compatibility methods
  def current_customer
    current_user
  end

  def customer_signed_in?
    user_signed_in?
  end

  def authenticate_customer!
    authenticate_user!
  end
end
