Rails.application.routes.draw do
  # Devise routes for user authentication (shared by admins and customers)
  devise_for :users, path_names: { sign_in: "login", sign_out: "logout" }

  # Mount Shopify App engine under connections namespace
  mount ShopifyApp::Engine, at: "/connections"

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Serve SVG icons for React components
  get "icons/:name", to: "icons#show", constraints: { name: /[^\/]+/ }

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

  # Auth handoff routes for JWT authentication
  get "auth/handoff", to: "auth#handoff"
  delete "auth/logout", to: "auth#logout", as: :logout

  # Defines the root path route ("/")
  root "dashboard#index"

  # Home (authenticated dashboard)
  get "home", to: "dashboard#index", as: :home

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
        get :toggle_active
        get :settings
        patch :update_fulfill_new_products
      end

      # Bulk fulfilment settings
      resource :bulk_fulfilment_settings, only: [], controller: "bulk_fulfilment_settings" do
        member do
          get :enable
          get :disable
        end
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

  # Customer orders management (customer-scoped)
  resources :orders, only: [ :index, :show ] do
    member do
      get :submit
      post :submit_production
      get :cancel_order
      get :reopen
      get :resync
      post :resend_email
    end

    # Fulfillments for orders
    resources :fulfillments, only: [ :new, :create ]

    # Nested order items for variant mapping management
    resources :order_items, only: [] do
      member do
        delete :remove_variant_mapping
        delete :soft_delete
        patch :restore
      end
    end
  end

  # Import orders
  resources :import_orders, only: [ :new, :create ]

  # Variant mappings for crop data
  resources :variant_mappings, only: [ :create, :update, :destroy ] do
    member do
      patch :sync_to_shopify
    end
  end

  # Custom print sizes for users
  resources :custom_print_sizes, only: [ :index, :create ]

  # Admin interface for internal management
  namespace :admin do
    root "dashboard#index"

    resources :stores, only: [ :index, :show, :edit, :update ] do
      member do
        post :sync_products
      end
    end

    resources :orders, only: [ :index, :show ] do
      member do
        get :submit
        get :cancel_order
        get :reopen
        get :resync
      end

      resources :order_items, only: [] do
        member do
          delete :remove_variant_mapping
          delete :soft_delete
          patch :restore
        end
      end
    end

    resources :users do
      member do
        post :impersonate
        post :invite
      end
      collection do
        delete :stop_impersonating
      end
    end

    resources :shopify_customers do
      member do
        post :create_company
      end
    end

    resources :companies
  end

  # Webhook endpoints (will be implemented in later phases)
  namespace :webhooks do
    post "app/uninstalled"
    post "orders/create"
    post "orders/paid", to: "orders#paid"
    post "products/create"
    post "products/update"
    post "fulfillments/create", to: "fulfillments#create"
    post "fulfillments/update", to: "fulfillments#update"
  end

  # Alias routes for Shopify webhooks (without /webhooks prefix)
  post "orders/paid", to: "webhooks/orders#paid"
  post "fulfillments/create", to: "webhooks/fulfillments#create"
  post "fulfillments/update", to: "webhooks/fulfillments#update"

  # Development-only route for letter_opener
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
