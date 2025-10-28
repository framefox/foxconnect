class Connections::DashboardController < Connections::ApplicationController
  def index
    # Check if user just completed OAuth by looking for shop param
    # and checking if that store was created very recently (within last 10 seconds)
    if params[:shop].present?
      shop_domain = params[:shop]
      store = current_user.stores.find_by(shopify_domain: shop_domain)

      if store && store.created_at > 10.seconds.ago
        redirect_to connections_store_path(store.uid, welcome: true) and return
      end
    end

    @connected_stores = current_user.stores.active.order(created_at: :desc)

    @platforms = [
      {
        name: "Shopify",
        slug: "shopify",
        description: "Connect your Shopify store to sync products and orders",
        icon: "shopify",
        connected: @connected_stores.shopify_stores.count,
        available: true
      },
      {
        name: "Squarespace",
        slug: "squarespace",
        description: "Connect your Squarespace store to sync products and orders",
        icon: "squarespace",
        connected: 0,
        available: false
      }
    ]

    @available_platforms = @platforms.select { |p| p[:available] }
  end
end
