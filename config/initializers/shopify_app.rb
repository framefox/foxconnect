# Initialize ShopifyAPI context first

# ShopifyAPI::Context.setup(
#   api_key: ENV["SHOPIFY_API_KEY"],
#   api_secret_key: ENV["SHOPIFY_API_SECRET"],
#   api_version: "2025-01",
#   host: "http://localhost:3000",
#   scope: "read_products,read_orders,write_orders,read_locations,read_fulfillments,read_inventory,read_customers,write_draft_orders",
#   is_embedded: false,
#   is_private: false
# )

ShopifyApp.configure do |config|
  config.application_name = "Framefox Connect"
  config.api_key = ENV["SHOPIFY_API_KEY"]
  config.secret = ENV["SHOPIFY_API_SECRET"]
  config.old_secret = ""

  # Scopes required for drop-shipping functionality
  config.scope = "read_products,read_orders,write_orders,read_locations,read_fulfillments,read_inventory,read_customers,write_draft_orders"

  # This is a non-embedded app (as requested)
  config.embedded_app = false

  # API version
  config.api_version = "2025-01"

  # Session storage configuration
  config.shop_session_repository = "Store"

  # Disable user sessions since we're only dealing with shop-level access
  config.user_session_repository = nil

  # Disable the new embedded auth strategy since we're not embedded
  config.new_embedded_auth_strategy = false

  # Root URL for redirects after authentication
  config.root_url = "/connections"

  # Login URL for initiating OAuth (now under /connections)
  config.login_url = "/connections/login"

  # Callback URL for OAuth redirect (now under /connections)
  config.login_callback_url = "/connections/auth/shopify/callback"
end
