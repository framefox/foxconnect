class AuthController < ApplicationController
  # Simple logout action - Devise handles all authentication
  def logout
    sign_out(current_user) if current_user
    redirect_to root_path, notice: "Logged out successfully"
  end
end
