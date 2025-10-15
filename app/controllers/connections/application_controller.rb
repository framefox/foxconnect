class Connections::ApplicationController < ApplicationController
  before_action :authenticate_user!

  protected

  def set_current_user
    # Use the user authentication from ApplicationController
    @current_user = current_user
  end
end
