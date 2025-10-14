class Connections::ApplicationController < ApplicationController
  before_action :authenticate_customer!

  protected

  def set_current_user
    # Use the customer authentication from ApplicationController
    @current_user = current_customer
  end
end
