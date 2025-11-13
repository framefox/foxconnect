# Sentry Integration Guide

This guide covers the Sentry error tracking integration for Framefox Connect, including both backend (Rails) and frontend (JavaScript) setup.

## Overview

Sentry provides real-time error tracking and monitoring for both backend and frontend code. This integration includes:

- **Backend**: Ruby gem integration with Rails, Sidekiq, and Active Record
- **Frontend**: JavaScript SDK for browser error tracking
- **Performance Monitoring**: Transaction tracing for API endpoints and user interactions
- **Session Replay**: Optional replay functionality to see what users did before an error occurred

## Installation

### 1. Install Dependencies

The dependencies have already been added to the project:

**Backend (Gemfile):**
```ruby
gem "sentry-ruby"
gem "sentry-rails"
gem "sentry-sidekiq"
```

**Frontend (package.json):**
```json
"@sentry/browser": "^8.0.0"
```

### 2. Install Gems and Packages

```bash
# Install Ruby gems
bundle install

# Install JavaScript packages
npm install
```

### 3. Rebuild JavaScript

```bash
npm run build
```

## Configuration

### Backend Configuration

The backend configuration is located in `config/initializers/sentry.rb` and follows the [latest Sentry documentation](https://docs.sentry.io/platforms/ruby/guides/rails/configuration/options/). 

Key features:

- **Environment-specific**: Only enabled in production and staging
- **Data Protection**: Automatically respects Rails' `filter_parameters` for sensitive data
- **Exception Filtering**: Common non-error exceptions (404s, routing errors) are excluded
- **User Context**: Automatically includes current user info with errors
- **Sidekiq Integration**: Tracks background job errors (only after retries exhausted)
- **Performance Monitoring**: Tracks database queries, API calls, and more
- **Session Tracking**: Automatically tracks user sessions in request/response cycles
- **Backtrace Cleaning**: Uses Rails' backtrace cleaner to remove gem/framework noise
- **Client Reports**: Sends diagnostic reports about dropped events
- **Breadcrumbs**: Tracks up to 50 events leading up to an error

#### Configuration Options

**Sampling Rates:**
- `sample_rate`: Error event sampling (default: 1.0 = 100% of errors)
- `traces_sample_rate`: Performance transaction sampling (default: 0.1 = 10% of transactions)

**Data & Privacy:**
- `send_default_pii`: Sends personally identifiable information (enabled with Rails filter protection)
- `send_client_reports`: Sends diagnostic reports about dropped events
- `send_modules`: Includes gem dependency information with errors
- `max_breadcrumbs`: Maximum number of breadcrumbs to store (set to 50)

**Release Tracking:**
- Automatically uses `APP_VERSION` environment variable
- Falls back to Heroku's `HEROKU_SLUG_COMMIT` if available
- Format: `framefox-connect@[commit-sha]`

### Frontend Configuration

The frontend configuration is located in `app/javascript/utils/sentry.js`. Key features:

- **Meta Tag Configuration**: Reads settings from Rails meta tags
- **User Context**: Automatically sets user info if logged in
- **Error Filtering**: Ignores common browser extension and network errors
- **Session Replay**: Captures session replays for debugging
- **Development Protection**: Doesn't send errors from localhost

## Setting Up Sentry Projects

### 1. Create Sentry Account

1. Go to [sentry.io](https://sentry.io)
2. Sign up for an account or log in
3. Create a new organization (or use existing)

### 2. Create Projects

You'll need to create **two separate projects** in Sentry:

#### Backend Project (Ruby/Rails)

1. Click "Projects" → "Create Project"
2. Select **Ruby** as the platform
3. Set alert frequency preferences
4. Name it: `framefox-connect-backend` (or similar)
5. Copy the DSN (looks like: `https://xxx@xxx.ingest.sentry.io/xxx`)
6. Add this DSN to your `config/application.yml` as `SENTRY_DSN`

#### Frontend Project (JavaScript)

1. Create another project
2. Select **JavaScript** as the platform
3. Name it: `framefox-connect-frontend` (or similar)
4. Copy the DSN
5. Add this DSN to your `config/application.yml` as `SENTRY_DSN_FRONTEND`

### 3. Update Environment Variables

Edit `config/application.yml` and uncomment/update the Sentry variables:

```yaml
# Development/default values
SENTRY_DSN: "https://your-backend-dsn@sentry.io/project-id"
SENTRY_DSN_FRONTEND: "https://your-frontend-dsn@sentry.io/project-id"
SENTRY_TRACES_SAMPLE_RATE: "0.1"
APP_VERSION: "1.0.0"

production:
  SENTRY_DSN: "https://your-production-backend-dsn@sentry.io/project-id"
  SENTRY_DSN_FRONTEND: "https://your-production-frontend-dsn@sentry.io/project-id"
  SENTRY_TRACES_SAMPLE_RATE: "0.1"
  APP_VERSION: "1.0.0"
```

**Important Notes:**
- Use **separate DSNs** for backend and frontend
- Use **different DSNs** for production and development/staging environments
- Keep these values secret (they're in `.gitignore` via Figaro)

## Configuration Options

### Sample Rates

The `SENTRY_TRACES_SAMPLE_RATE` controls what percentage of transactions are sent to Sentry for performance monitoring:

- `0.0` = No performance monitoring (only errors)
- `0.1` = 10% of transactions (recommended for production)
- `1.0` = 100% of transactions (use for development/staging only)

**Why not 100%?** Performance monitoring data can be expensive at scale. Start with 10% and adjust based on your needs.

### App Version

Set `APP_VERSION` to track which version of your app has errors:

- Manual: `APP_VERSION: "1.0.0"`
- Git SHA: Automatically uses git commit hash if not set
- Deployment: Update this during deployments to track releases

## Testing the Integration

### Backend Testing

Test backend error tracking in Rails console:

```ruby
# In Rails console
rails c

# Manually trigger an error
Sentry.capture_message("Test message from Rails console")

# Or trigger an exception
begin
  raise "Test exception"
rescue => e
  Sentry.capture_exception(e)
end
```

Check your Sentry backend project dashboard - you should see the error appear within seconds.

### Frontend Testing

Test frontend error tracking in browser console:

```javascript
// In browser console
Sentry.captureMessage("Test message from browser");

// Or trigger an error
throw new Error("Test frontend error");
```

Check your Sentry frontend project dashboard.

### Test in Code

Add temporary test code to trigger errors:

**Backend (in any controller):**
```ruby
def test_sentry
  raise "Testing Sentry backend integration"
end
```

**Frontend (in any JavaScript file):**
```javascript
throw new Error("Testing Sentry frontend integration");
```

## Manual Error Reporting

### Backend (Ruby/Rails)

```ruby
# Capture a message
Sentry.capture_message("Something important happened", level: :info)

# Capture an exception
begin
  # risky code
rescue StandardError => e
  Sentry.capture_exception(e)
end

# Add custom context
Sentry.set_context("payment", {
  amount: 1000,
  currency: "NZD"
})

# Add tags
Sentry.set_tags(feature: "checkout", action: "payment")

# Add breadcrumbs
Sentry.add_breadcrumb(
  message: "User clicked checkout",
  category: "user.interaction",
  level: :info
)
```

### Frontend (JavaScript)

```javascript
import Sentry from './utils/sentry';

// Capture a message
Sentry.captureMessage('Something happened', 'info');

// Capture an exception
try {
  // risky code
} catch (error) {
  Sentry.captureException(error);
}

// Add custom context
Sentry.setContext('payment', {
  amount: 1000,
  currency: 'NZD'
});

// Add tags
Sentry.setTags({ feature: 'checkout', action: 'payment' });

// Add breadcrumbs
Sentry.addBreadcrumb({
  message: 'User clicked checkout button',
  category: 'user.interaction',
  level: 'info'
});
```

## Understanding Sentry Dashboard

### Issues

- **Issues**: Grouped errors (same error = same issue)
- **Events**: Individual occurrences of an error
- **Releases**: Track which version has which errors
- **Environments**: Separate dev/staging/production errors

### Key Metrics to Watch

1. **Error Rate**: Errors per minute/hour
2. **Affected Users**: How many users hit errors
3. **MTTR**: Mean time to resolution
4. **New vs Regressed**: New errors vs previously fixed ones

### Alerts

Set up alerts to notify you when:
- New issues are created
- Error rate spikes
- Specific errors occur
- Errors affect X% of users

## Production Deployment

### Before Deploying

1. ✅ Uncomment Sentry DSN variables in `config/application.yml`
2. ✅ Set actual DSN values from Sentry dashboard
3. ✅ Set `APP_VERSION` to current version
4. ✅ Verify `SENTRY_TRACES_SAMPLE_RATE` is reasonable (0.1 recommended)
5. ✅ Test locally with staging DSNs first

### Deployment Checklist

```bash
# 1. Update app version
# Edit config/application.yml and set APP_VERSION

# 2. Commit changes
git add .
git commit -m "Configure Sentry for production"

# 3. Deploy
# Use your normal deployment process
```

### Verify Deployment

1. Visit your production app
2. Check Sentry dashboard for initialization events
3. Test an intentional error (if safe)
4. Verify errors appear in Sentry

## Troubleshooting

### Errors Not Appearing in Sentry

**Backend:**
1. Check `SENTRY_DSN` is set correctly
2. Verify you're in production/staging environment
3. Check Rails logs for Sentry initialization
4. Test with `Sentry.capture_message("test")`

**Frontend:**
1. Check browser console for Sentry initialization message
2. Verify meta tags are present: `<meta name="sentry-dsn" content="...">`
3. Check `SENTRY_DSN_FRONTEND` is set correctly
4. Ensure JavaScript bundle was rebuilt after installing Sentry

### Too Many Errors

If you're getting flooded with errors:

1. **Increase ignored exceptions** in `config/initializers/sentry.rb`
2. **Add frontend ignore patterns** in `app/javascript/utils/sentry.js`
3. **Set up error filters** in Sentry dashboard
4. **Reduce sample rate** temporarily

### Development Errors Appearing

By default, Sentry is disabled in development:

- Backend: Only enabled in `production` and `staging` environments
- Frontend: Checks for localhost and skips sending

If you want to test in development, temporarily modify the environment checks.

## Best Practices

### Do's ✅

- Monitor Sentry dashboard regularly
- Set up Slack/email alerts for critical errors
- Add context to errors (user actions, data involved)
- Use tags to categorize errors (feature, module, action)
- Update `APP_VERSION` with each deployment
- Create releases in Sentry for better tracking

### Don'ts ❌

- Don't send sensitive data (passwords, tokens) to Sentry
- Don't set sample rate to 100% in production
- Don't ignore all errors - fix them!
- Don't expose DSN publicly (keep in .gitignore)
- Don't use same DSN for frontend and backend

## Security Considerations

### PII Protection

The integration automatically filters sensitive data:

- **Backend**: Sentry 6.x+ automatically respects `Rails.application.config.filter_parameters`
- **Frontend**: User data only sent if explicitly set via `Sentry.setUser()`

### Sensitive Fields

In Sentry 6.x+, there's no need to manually configure `sanitize_fields`. The SDK automatically filters any fields matching your Rails filter parameters.

These are automatically filtered by Rails by default:
- Passwords
- Tokens
- API keys
- Credit card numbers
- Any field matching Rails filter parameters

To add more filters, update `config/initializers/filter_parameter_logging.rb`:

```ruby
Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate, :otp, :ssn,
  :secret_field, :sensitive_data, :api_key, :private_key
]
```

**Note**: Sentry SDK version 6.x+ automatically respects these Rails filters without additional configuration. The deprecated `sanitize_fields` option has been removed from the configuration.

## Support and Documentation

- [Sentry Ruby Documentation](https://docs.sentry.io/platforms/ruby/)
- [Sentry Rails Guide](https://docs.sentry.io/platforms/ruby/guides/rails/)
- [Sentry JavaScript Documentation](https://docs.sentry.io/platforms/javascript/)
- [Sentry Browser Guide](https://docs.sentry.io/platforms/javascript/guides/browser/)

## Summary

Sentry is now integrated and ready to track errors in both backend and frontend:

1. ✅ Backend tracking with Rails, Sidekiq integration
2. ✅ Frontend tracking with browser SDK
3. ✅ Performance monitoring enabled
4. ✅ User context automatically included
5. ✅ Sensitive data filtered
6. ✅ Environment-specific configuration

To activate, simply:
1. Create Sentry projects
2. Add DSNs to `config/application.yml`
3. Deploy to production/staging
4. Monitor your Sentry dashboard!

