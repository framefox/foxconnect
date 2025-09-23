Rails.application.routes.draw do
  # Mount Shopify App engine for authentication and webhooks
  mount ShopifyApp::Engine, at: "/"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  root "home#index"

  # Admin interface for managing Shopify connections
  namespace :admin do
    root "dashboard#index"
    resources :stores, only: [ :index, :show, :destroy ] do
      member do
        post :sync_products
      end
    end
  end

  # Webhook endpoints (will be implemented in later phases)
  namespace :webhooks do
    post "app/uninstalled"
    post "orders/create"
    post "products/create"
    post "products/update"
  end
end
