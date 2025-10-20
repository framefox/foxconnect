class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  include ToastNotifications

  # Include Pagy Backend for pagination
  include Pagy::Backend

  # Devise provides: current_user, user_signed_in?, authenticate_user!
  # Additional helpers
  helper_method :impersonating?, :impersonated_user
  # Backwards compatibility helpers
  helper_method :current_customer, :customer_signed_in?

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

  # Devise redirect after sign in based on user role
  def after_sign_in_path_for(resource)
    if resource.admin?
      admin_root_path
    else
      root_path
    end
  end
end
