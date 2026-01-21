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

  # Auth logout route (login handled by Devise)
  delete "auth/logout", to: "auth#logout", as: :logout

  # Defines the root path route ("/") - marketing homepage
  root "pages#home"

  # Home (authenticated dashboard)
  get "home", to: "dashboard#index", as: :home

  # Static pages
  get "policy", to: "pages#privacy_policy", as: :privacy_policy
  get "faq", to: "pages#faq", as: :faq
  get "terms", to: "pages#terms_of_service", as: :terms_of_service

  # Application form
  get "apply", to: "applications#new", as: :apply
  post "apply", to: "applications#create"
  get "apply/thank-you", to: "applications#thank_you", as: :apply_thank_you

  # Connections management - main customer interface
  namespace :connections do
    root "dashboard#index"

    # Platform-specific connection routes
    namespace :shopify do
      get "connect", to: "auth#connect"
      get "callback", to: "auth#callback"
      delete "disconnect/:uid", to: "auth#disconnect", as: :disconnect
    end

    namespace :squarespace do
      get "connect", to: "auth#connect"
      get "callback", to: "auth#callback"
      delete "disconnect/:uid", to: "auth#disconnect", as: :disconnect
    end

    # Store management within connections
    resources :stores, only: [ :show, :destroy ], param: :uid do
      member do
        get :sync_products
        get :check_products
        get :toggle_active
        get :settings
        patch :update_fulfill_new_products
        patch :update_settings
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
          get :toggle_bundles # Toggle bundles enabled/disabled for this product
        end

        # AI-powered variant mapping (nested under products)
        post "ai_variant_mapping/suggest", to: "stores/ai_variant_mappings#suggest"
        post "ai_variant_mapping/create", to: "stores/ai_variant_mappings#create"
      end

      # Product variants for fulfilment toggling
      resources :product_variants, only: [], controller: "stores/product_variants" do
        member do
          patch :toggle_fulfilment # API endpoint for toggling variant fulfilment status
          patch :set_fulfilment # API endpoint for setting specific fulfilment state
          patch :update_bundle # API endpoint for updating bundle slot count
        end
      end
    end
  end

  # Customer orders management (customer-scoped)
  resources :orders, only: [ :index, :show, :new, :create ] do
    member do
      get :submit
      post :submit_production
      get :cancel_order
      get :reopen
      get :resync
      post :sync_missing_products
      post :resend_email
    end

    # Fulfillments for orders
    resources :fulfillments, only: [ :new, :create ]

    # Shipping address for orders (singular resource - one per order)
    resource :shipping_address, only: [ :new, :edit, :create, :update ]

    # Nested order items for variant mapping management
    resources :order_items, only: [ :create ] do
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
      delete :remove_image
    end
  end

  # Custom print sizes for users
  resources :custom_print_sizes, only: [ :index, :create ]

  # Saved frame SKUs for users
  resources :saved_items, only: [ :index, :create, :destroy ]

  # Uploads management
  resources :uploads, only: [ :index ]

  # Products browser
  resources :products, only: [ :index ]

  # Admin interface for internal management
  namespace :admin do
    root "dashboard#index"

    resources :stores, only: [ :index, :show, :edit, :update, :destroy ], param: :uid do
      collection do
        post :flag_stores_missing_scopes
      end
      member do
        post :sync_products
        post :test_api_connection
        post :request_reauthentication
      end

      resources :products, only: [ :new, :create ], controller: "stores/products" do
        member do
          get :duplicate
          post :create_duplicate
        end
      end
    end

    resources :orders, only: [ :index, :show, :destroy ] do
      member do
        get :submit
        get :cancel_order
        get :reopen
        get :resync
        post :resend_email
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

    resources :organizations

    resources :webhook_logs, only: [ :index, :show ]
  end

  # Webhook endpoints
  namespace :webhooks do
    # =============================================================================
    # MERCHANT STORE WEBHOOKS (from stores that install the app)
    # These webhooks require HMAC verification for security
    # =============================================================================

    # App lifecycle webhooks
    post "app/uninstalled", to: "app#uninstalled"

    # Order webhooks - NEW orders from merchant stores
    post "orders/create", to: "orders#create"

    # Product webhooks - Product changes in merchant stores
    post "products/create", to: "products#create"
    post "products/update", to: "products#update"

    # GDPR compliance webhooks (mandatory for App Store)
    post "customers/data_request", to: "gdpr#customers_data_request"
    post "customers/redact", to: "gdpr#customers_redact"
    post "shop/redact", to: "gdpr#shop_redact"

    # =============================================================================
    # FULFILLMENT SERVICE CALLBACKS
    # These are sent by Shopify to the callback_url registered with our fulfillment service
    # =============================================================================

    # Fulfillment order notifications - when merchant clicks "Request fulfillment" or "Cancel"
    post "fulfillment_order_notification", to: "fulfillment_order_notifications#create"

    # Fulfillment order webhooks (alternative to callback - for event-driven updates)
    post "fulfillment_orders/fulfillment_request_submitted", to: "fulfillment_order_notifications#create"
    post "fulfillment_orders/cancellation_request_submitted", to: "fulfillment_order_notifications#create"

    # =============================================================================
    # FRAMEFOX PRODUCTION STORE WEBHOOKS (from Framefox's own Shopify stores)
    # These webhooks do NOT require HMAC verification (internal system)
    # =============================================================================

    # Order payment confirmation - Framefox Production charged the merchant
    post "orders/paid", to: "production_orders#paid"

    # Fulfillment tracking - Framefox Production fulfillment updates
    post "fulfillments/create", to: "production_fulfillments#create"
    post "fulfillments/update", to: "production_fulfillments#update"
  end

  # Development-only route for letter_opener
  if Rails.env.development?
    mount LetterOpenerWeb::Engine, at: "/letter_opener"
  end
end
