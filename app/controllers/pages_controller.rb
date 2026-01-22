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

  def terms_of_service
  end

  def organization_required
    # Shown when a user has no organization assigned
    # They need to contact support or an admin to be assigned to an organization
  end
end
