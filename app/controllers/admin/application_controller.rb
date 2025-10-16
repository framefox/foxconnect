class Admin::ApplicationController < ApplicationController
  layout "admin"

  before_action :authenticate_user!
  before_action :require_admin!

  private

  def require_admin!
    unless current_user&.admin?
      redirect_to root_path, alert: "Access denied. Admin privileges required."
    end
  end
end
