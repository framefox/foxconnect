# Sentry error tracking configuration
# https://docs.sentry.io/platforms/ruby/guides/rails/
# https://docs.sentry.io/platforms/ruby/guides/rails/configuration/options/

Sentry.init do |config|
  # ====================
  # Core Options
  # ====================

  # Set the Sentry DSN from environment variables
  # If not provided, SDK will try to read from SENTRY_DSN env var
  config.dsn = ENV["SENTRY_DSN"]

  # Enable Sentry only in production and staging environments
  config.enabled_environments = %w[production staging]

  # Set the current environment
  config.environment = Rails.env

  # Set release version for tracking which version has bugs
  # Sentry automatically detects releases from git, Heroku, Capistrano, etc.
  config.release = ENV["APP_VERSION"] || "framefox-connect@#{ENV['HEROKU_SLUG_COMMIT']&.slice(0, 7)}"

  # ====================
  # Sampling Options
  # ====================

  # Error event sample rate (0.0 to 1.0)
  # 1.0 means 100% of error events will be sent
  config.sample_rate = 1.0

  # Performance monitoring: transaction sample rate (0.0 to 1.0)
  # 0.1 means 10% of transactions will be sent to Sentry
  config.traces_sample_rate = ENV.fetch("SENTRY_TRACES_SAMPLE_RATE", 0.1).to_f

  # ====================
  # Data & Privacy Options
  # ====================

  # Send personally identifiable information (PII) with events
  # WARNING: When enabled, request data, user IPs, and other PII will be sent to Sentry
  # Sentry will automatically respect Rails.application.config.filter_parameters
  config.send_default_pii = true

  # Send diagnostic client reports about dropped events (recommended)
  config.send_client_reports = true

  # Send gem/module dependency information with events
  config.send_modules = true

  # ====================
  # Breadcrumbs
  # ====================

  # Maximum number of breadcrumbs to store (default: 100)
  config.max_breadcrumbs = 50

  # Breadcrumbs are a trail of events that happened prior to an error
  # :active_support_logger - Rails-specific info via ActiveSupport instrumentation
  # :http_logger - Captures requests made with net/http library
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]

  # ====================
  # Exception Filtering
  # ====================

  # Exclude certain exception types that are not actionable errors
  config.excluded_exceptions += [
    "ActionController::RoutingError",
    "ActiveRecord::RecordNotFound",
    "ActionController::InvalidAuthenticityToken",
    "ActionController::UnknownFormat",
    "ActionDispatch::Http::MimeNegotiation::InvalidType"
  ]

  # ====================
  # Callbacks & Hooks
  # ====================

  # Clean up backtrace before sending to Sentry (removes gem/framework noise)
  config.backtrace_cleanup_callback = lambda do |backtrace|
    Rails.backtrace_cleaner.clean(backtrace)
  end

  # Modify or filter events before sending to Sentry
  config.before_send = lambda do |event, hint|
    # Add custom user context if logged in
    if defined?(Current) && Current.user
      event.user = {
        id: Current.user.id,
        email: Current.user.email,
        username: Current.user.email
      }
    end

    # Add custom tags
    event.tags[:subdomain] = Current.subdomain if defined?(Current) && Current.subdomain

    # Return event to send it, or return nil to drop it
    event
  end

  # ====================
  # Rails Integration
  # ====================

  # Automatically track user sessions in request/response cycles
  config.auto_session_tracking = true

  # Note: Performance tracing subscribers are automatically enabled in sentry-rails 6.x
  # The config.rails.tracing_subscribers option is only available in Sentry 7.0+
  # Sentry 6.x automatically instruments:
  # - Active Record queries
  # - Action Controller requests
  # - Action View rendering
  # - Active Storage operations

  # ====================
  # Background Jobs (Sidekiq)
  # ====================

  # Only report Sidekiq jobs after all retries have been exhausted
  config.sidekiq.report_after_job_retries = true

  # ====================
  # Debug & Logging
  # ====================

  # Enable debug mode to see SDK errors with backtrace (not recommended for production)
  # config.debug = true

  # Adjust SDK logger level if you need more output (not recommended for production)
  # config.logger.level = ::Logger::DEBUG
end
