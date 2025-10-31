class UploadsController < ApplicationController
  before_action :authenticate_user!

  def index
    # The React component will handle fetching images from the external Framefox API
    # No data needs to be passed from the controller
  end
end

