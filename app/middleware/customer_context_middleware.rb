class CustomerContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Get session from rack env
    session = env["rack.session"] || {}

    # Set customer ID in thread if present in session
    # Priority: impersonated_customer_id (database ID) > lookup by external_shopify_id
    if session[:impersonating] && session[:impersonated_customer_id]
      # When impersonating, use the database ID directly
      Thread.current[:current_shopify_customer_id] = session[:impersonated_customer_id]
    elsif session[:shopify_customer_id]
      # When not impersonating, lookup customer by external ID to get database ID
      customer = ShopifyCustomer.find_by(external_shopify_id: session[:shopify_customer_id])
      Thread.current[:current_shopify_customer_id] = customer&.id
    end

    # Call the next middleware/app
    @app.call(env)
  ensure
    # Always clean up thread variable after request
    Thread.current[:current_shopify_customer_id] = nil
  end
end
