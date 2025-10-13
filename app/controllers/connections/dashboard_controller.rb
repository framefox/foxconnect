class Connections::DashboardController < Connections::ApplicationController
  def index
    @connected_stores = current_customer.stores.active.order(created_at: :desc)
    @total_stores = current_customer.stores.count
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
