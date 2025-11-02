class ProductsController < ApplicationController
  before_action :authenticate_user!

  def index
    # The React component will handle fetching product data from the external Framefox API
    # No data needs to be passed from the controller
  end
end

