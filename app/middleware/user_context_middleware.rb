class UserContextMiddleware
  def initialize(app)
    @app = app
  end

  def call(env)
    # Get session from rack env
    session = env["rack.session"] || {}

    # Set user in RequestStore if present
    # Priority: impersonated_user_id > Devise authenticated user
    if session[:impersonating] && session[:impersonated_user_id]
      # When impersonating, use the impersonated user directly
      RequestStore[:current_user] = User.find_by(id: session[:impersonated_user_id])
    else
      # Get user from Devise/Warden
      # Warden is available in the env and manages user sessions for Devise
      warden = env["warden"]
      if warden
        begin
          # Try to get the user - warden.user without args gets the default scope
          user = warden.user
          RequestStore[:current_user] = user if user
        rescue => e
          # Log the error but don't break the request
          Rails.logger.warn "UserContextMiddleware: Failed to get user from Warden: #{e.message}"
        end
      end
    end

    # Call the next middleware/app
    @app.call(env)
  end
end
