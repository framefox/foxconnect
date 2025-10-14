class DashboardController < ApplicationController
  before_action :authenticate_customer!

  def index
    # Placeholder stats - replace with real data later
  end
end
