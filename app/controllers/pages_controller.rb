class PagesController < ApplicationController
  layout "public"

  def home
    # Marketing homepage - no authentication required
    # Redirect authenticated users to their dashboard
    redirect_to home_path if user_signed_in?
  end

  def privacy_policy
  end

  def faq
  end
end
