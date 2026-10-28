class PagesController < ApplicationController
  layout "public"

  def home
    # Shopify returns installations and app launches to application_url, not
    # directly to the OAuth callback. Continue the authenticated connection flow.
    if params[:shop].present?
      shop = ShopifyAPI::Utils::ShopValidator.sanitize_shop_domain(params[:shop].to_s)
      return head :bad_request if shop.blank?

      return redirect_to connections_shopify_connect_path(shop: shop)
    end

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
