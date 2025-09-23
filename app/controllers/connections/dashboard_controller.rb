class Connections::DashboardController < Connections::ApplicationController
  def index
    @connected_stores = Store.active.order(created_at: :desc)
    @total_stores = Store.count
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
        name: "WooCommerce", 
        slug: "woocommerce",
        description: "WordPress e-commerce integration (Coming in Phase 4)",
        icon: "woocommerce",
        connected: 0,
        available: false
      },
      {
        name: "Etsy",
        slug: "etsy", 
        description: "Marketplace integration for handmade goods (Coming in Phase 4)",
        icon: "etsy",
        connected: 0,
        available: false
      }
    ]
    
    @available_platforms = @platforms.select { |p| p[:available] }
  end
end
