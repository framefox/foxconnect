class AuthController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [ :handoff ]

  def handoff
    token = params[:token]

    unless token
      redirect_to root_path, alert: "Invalid authentication token"
      return
    end

    payload = JwtTokenService.decode(token)

    unless payload
      redirect_to root_path, alert: "Invalid or expired token"
      return
    end

    user = find_or_create_user_and_shopify_customer(payload)

    if user
      sign_in(user)
      redirect_to connections_root_path, notice: "Successfully logged in"
    else
      redirect_to root_path, alert: "Authentication failed"
    end
  end

  def logout
    sign_out(current_user) if current_user
    redirect_to root_path, notice: "Logged out successfully"
  end

  private

  def find_or_create_user_and_shopify_customer(payload)
    # Find or create User by email
    user = User.find_or_create_by(email: payload["email"]) do |u|
      u.first_name = payload["first_name"]
      u.last_name = payload["last_name"]
    end

    # Find or create ShopifyCustomer by external_shopify_id, linking to User
    ShopifyCustomer.find_or_create_by(external_shopify_id: payload["shopify_customer_id"]) do |customer|
      customer.user = user
    end

    user
  end
end
