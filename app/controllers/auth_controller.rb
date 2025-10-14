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

    customer = find_or_create_customer(payload)

    if customer
      session[:shopify_customer_id] = customer.external_shopify_id
      redirect_to connections_root_path, notice: "Successfully logged in"
    else
      redirect_to root_path, alert: "Authentication failed"
    end
  end

  def logout
    reset_session
    redirect_to root_path, notice: "Logged out successfully"
  end

  private

  def find_or_create_customer(payload)
    ShopifyCustomer.find_or_create_by(external_shopify_id: payload["shopify_customer_id"]) do |customer|
      customer.email = payload["email"]
      customer.first_name = payload["first_name"]
      customer.last_name = payload["last_name"]
    end
  end
end
