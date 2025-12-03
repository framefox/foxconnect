# Production API Authentication Fix

## Issue

**Date:** December 3, 2025  
**Environment:** Production (Heroku)  
**Error:** 401 Unauthorized when submitting orders to production

### Error Log
```
2025-12-03T01:07:57.626549+00:00 app[web.1]: Production API error: Client error (401 Unauthorized): Unauthorized
2025-12-03T01:07:57.630057+00:00 app[web.1]: Completed 422 Unprocessable Content in 130ms
```

## Root Cause

The `Production::ApiClient` service was making API requests to the production API (`shop.framefox.co.nz` or `shop.framefox.com.au`) without sending any authentication credentials. The production API requires an API key to be sent as a query parameter named `auth`.

### Code Location
- **File:** `app/services/production/api_client.rb`
- **Method:** `send_to_api`

### Before Fix
```ruby
def send_to_api(payload)
  response = HTTP
    .timeout(connect: 10, read: 30)
    .headers("Content-Type" => "application/json", "Accept" => "application/json")
    .post(api_url, json: payload)  # Missing auth parameter!

  handle_response(response)
  # ...
end
```

## Solution

Added the `FRAMEFOX_API_KEY` environment variable as a query parameter named `auth` to the API request URL.

### After Fix
```ruby
def send_to_api(payload)
  # Build the URL with auth parameter
  url_with_auth = if ENV["FRAMEFOX_API_KEY"].present?
    "#{api_url}?auth=#{ENV['FRAMEFOX_API_KEY']}"
  else
    api_url
  end

  response = HTTP
    .timeout(connect: 10, read: 30)
    .headers("Content-Type" => "application/json", "Accept" => "application/json")
    .post(url_with_auth, json: payload)

  handle_response(response)
  # ...
end
```

## Required Environment Variable

The following environment variable must be set in production (Heroku):

```bash
FRAMEFOX_API_KEY=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3
```

This is already defined in `config/application.yml` for local development. For production, verify it's set in Heroku:

```bash
heroku config:get FRAMEFOX_API_KEY -a framefox-connect
```

If not set, add it:

```bash
heroku config:set FRAMEFOX_API_KEY=0936ac0193ec48f7f88d38c1518572a2e5f8a5c3 -a framefox-connect
```

## Authentication Pattern

The production API uses **query parameter authentication** rather than header-based authentication:

- **Frontend (JavaScript):** Already implemented correctly in components like `ProductSelectModal.js`, `UploadsManager.js`, etc.
  ```javascript
  axios.get(`${baseApiUrl}/frame_skus.json`, {
    params: apiAuthToken ? { auth: apiAuthToken } : {}
  });
  ```

- **Backend (Ruby):** Now fixed in `Production::ApiClient`
  ```ruby
  url_with_auth = "#{api_url}?auth=#{ENV['FRAMEFOX_API_KEY']}"
  ```

## Testing

### Test Locally
1. Ensure `FRAMEFOX_API_KEY` is set in `config/application.yml`
2. Try submitting an order to production from your local environment
3. Check logs for successful API communication

### Test in Production
1. Verify environment variable is set in Heroku
2. Submit a test order through the UI
3. Monitor Heroku logs for successful production API communication:
   ```bash
   heroku logs --tail -a framefox-connect
   ```

## Related Files

- `app/services/production/api_client.rb` - Production API client (fixed)
- `app/services/order_production_service.rb` - Orchestrates order submission workflow
- `app/controllers/orders_controller.rb` - Handles order submission requests
- `config/application.yml` - Contains `FRAMEFOX_API_KEY` configuration
- `app/helpers/application_helper.rb` - Provides `framefox_api_config` to frontend

## Future Considerations

1. **API Key Rotation:** If the API key needs to be changed, update it in:
   - Heroku environment variables (`heroku config:set`)
   - `config/application.yml` (for local development)

2. **Error Handling:** The current implementation gracefully handles missing API keys by falling back to the unauthenticated URL. Consider adding a warning log when the API key is missing.

3. **Alternative Authentication:** If the production API ever migrates to header-based authentication (e.g., `Authorization: Bearer <token>`), update the `send_to_api` method accordingly.

## Deployment Notes

After deploying this fix:
1. No database migrations required
2. No config changes required (assuming `FRAMEFOX_API_KEY` is already set in Heroku)
3. Restart the app if needed: `heroku restart -a framefox-connect`
4. Test order submission immediately after deployment

