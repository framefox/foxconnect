Rails.application.routes.draw do
  # Mount Shopify App engine under connections namespace
  mount ShopifyApp::Engine, at: "/connections"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Toast demo routes
  resources :toast_demo, only: [ :index ] do
    collection do
      post :show_success, path: "success"
      post :show_error, path: "error"
      post :show_warning, path: "warning"
      post :show_info, path: "info"
    end
  end

  # Defines the root path route ("/")
  root "home#index"

  # Connections management - main customer interface
  namespace :connections do
    root "dashboard#index"

    # Platform-specific connection routes
    namespace :shopify do
      get "connect", to: "auth#connect"
      get "callback", to: "auth#callback"
      delete "disconnect/:id", to: "auth#disconnect", as: :disconnect
    end

    # Store management within connections
    resources :stores, only: [ :show, :destroy ] do
      member do
        get :sync_products
        patch :toggle_active
      end

      # Individual products for each store (no index needed)
      resources :products, only: [ :show ], controller: "stores/products" do
        member do
          get :sync_from_platform
          patch :toggle_fulfilment # API endpoint for toggling fulfilment status
          get :sync_variant_mappings # Sync all variant mappings for this product
        end
      end

      # Product variants for fulfilment toggling
      resources :product_variants, only: [], controller: "stores/product_variants" do
        member do
          patch :toggle_fulfilment # API endpoint for toggling variant fulfilment status
          patch :set_fulfilment # API endpoint for setting specific fulfilment state
        end
      end
    end
  end

  # Orders management
  resources :orders, only: [ :index, :show ] do
    member do
      patch :submit
      patch :start_production
      patch :cancel_order
      patch :reopen
      get :resync
    end

    # Nested order items for variant mapping management
    resources :order_items, only: [] do
      member do
        delete :remove_variant_mapping
      end
    end
  end

  # Import orders
  resources :import_orders, only: [ :new, :create ]

  # Variant mappings for crop data
  resources :variant_mappings, only: [ :create, :destroy ] do
    member do
      patch :sync_to_shopify
    end
  end

  # Admin interface for internal management
  namespace :admin do
    root "dashboard#index"
    resources :stores, only: [ :index, :show ]
    resources :users, only: [ :index, :show ]
  end

  # Webhook endpoints (will be implemented in later phases)
  namespace :webhooks do
    post "app/uninstalled"
    post "orders/create"
    post "products/create"
    post "products/update"
  end
end
