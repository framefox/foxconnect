class Admin::DashboardController < Admin::ApplicationController
  def index
    @current_store = Store.find_by(shopify_domain: current_shopify_session.shop) if current_shopify_session
    @stores_count = Store.active.count
    @total_stores = Store.count
  end
end
