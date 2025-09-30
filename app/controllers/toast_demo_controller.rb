class ToastDemoController < ApplicationController
  def index
  end

  def show_success
    toast_success("This is a success message! Everything worked perfectly.")
    redirect_to toast_demo_index_path
  end

  def show_error
    toast_error("This is an error message! Something went wrong.")
    redirect_to toast_demo_index_path
  end

  def show_warning
    toast_warning("This is a warning message! Please be careful.")
    redirect_to toast_demo_index_path
  end

  def show_info
    toast_info("This is an info message! Here's some useful information.")
    redirect_to toast_demo_index_path
  end
end
