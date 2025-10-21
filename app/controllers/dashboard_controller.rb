class DashboardController < ApplicationController
  before_action :authenticate_customer!

  def index
    # Get recent activities from user's orders
    @recent_activities = OrderActivity
      .joins(:order)
      .where(orders: { store_id: current_user.stores.pluck(:id) })
      .order(occurred_at: :desc)
      .limit(10)
      .includes(:order)
  end
end
