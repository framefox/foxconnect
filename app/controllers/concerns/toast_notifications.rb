module ToastNotifications
  extend ActiveSupport::Concern

  private

  def toast_success(message)
    flash[:notice] = message
  end

  def toast_error(message)
    flash[:alert] = message
  end

  def toast_warning(message)
    flash[:warning] = message
  end

  def toast_info(message)
    flash[:info] = message
  end
end
