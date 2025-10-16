class Admin::DashboardController < Admin::ApplicationController
  def index
    # Admin users don't have a specific "current store" - they can view all stores
    @stores_count = Store.active.count
    @total_stores = Store.count
  end
end
