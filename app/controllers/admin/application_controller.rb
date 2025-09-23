class Admin::ApplicationController < ApplicationController
  include ShopifyApp::LoginProtection

  layout "admin"

  before_action :login_again_if_different_user_or_shop

  protected

  def login_again_if_different_user_or_shop
    return unless session[:shopify_domain]
    return if current_shopify_session&.shop == session[:shopify_domain]

    clear_shopify_session
    redirect_to login_url
  end
end
