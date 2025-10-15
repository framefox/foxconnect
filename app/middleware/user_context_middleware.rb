class UserContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Get session from rack env
    session = env["rack.session"] || {}

    # Set user ID in thread if present in session
    # Priority: impersonated_user_id > user_id
    if session[:impersonating] && session[:impersonated_user_id]
      # When impersonating, use the impersonated user ID directly
      Thread.current[:current_user_id] = session[:impersonated_user_id]
    elsif session[:user_id]
      # Normal authentication
      Thread.current[:current_user_id] = session[:user_id]
    end

    # Call the next middleware/app
    @app.call(env)
  ensure
    # Always clean up thread variable after request
    Thread.current[:current_user_id] = nil
  end
end
