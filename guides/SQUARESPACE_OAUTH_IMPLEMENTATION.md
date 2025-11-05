# Squarespace OAuth Integration Implementation

## Summary

Implemented Squarespace OAuth authentication flow to allow users to connect their Squarespace stores to Framefox Connect. This implementation provides full read/write access to products and orders via the Squarespace Commerce APIs.

## Overview

The Squarespace integration follows the same architectural pattern as the existing Shopify integration, with platform-specific OAuth controllers, API service layer, and model concerns for store management.

## Changes Made

### 1. OAuth Routes (`config/routes.rb`)

Added Squarespace-specific OAuth routes under the `connections` namespace:

```ruby
namespace :squarespace do
  get "connect", to: "auth#connect"
  get "callback", to: "auth#callback"
  delete "disconnect/:uid", to: "auth#disconnect", as: :disconnect
end
```

**Routes:**
- `GET /connections/squarespace/connect` - Initiates OAuth flow
- `GET /connections/squarespace/callback` - Handles OAuth callback
- `DELETE /connections/squarespace/disconnect/:uid` - Disconnects store

### 2. Auth Controller (`app/controllers/connections/squarespace/auth_controller.rb`)

Created `Connections::Squarespace::AuthController` with three actions:

**`connect` Action:**
- Generates CSRF token (stored in session as `squarespace_oauth_state`)
- Builds OAuth authorization URL with required parameters
- Redirects user to Squarespace login page

**OAuth Parameters:**
- `client_id`: From ENV['SQUARESPACE_CLIENT_ID']
- `redirect_uri`: Dynamically built from request (handles localhost:3000 and connect.framefox.com)
- `scope`: `website.orders,website.products,website.inventory` (read/write access)
- `state`: CSRF protection token
- `access_type`: `offline` (for long-lived tokens)

**Scope Format:**
- Base scopes (e.g., `website.orders`) grant read AND write access
- Read-only scopes use `.read` suffix (e.g., `website.orders.read`)
- Available scopes: `website.orders`, `website.products`, `website.inventory`, `website.transactions.read`

**`callback` Action:**
- Verifies state parameter (CSRF protection)
- Exchanges authorization code for access token
- Fetches site information from Squarespace API
- Creates or updates Store record with:
  - platform: "squarespace"
  - squarespace_token: access token
  - squarespace_domain: site identifier (siteId)
  - name: site title
  - user: current authenticated user
- Redirects to store management page on success

**`disconnect` Action:**
- Finds and destroys the store record
- Only allows disconnection of stores owned by current user
- Redirects back to connections dashboard

### 3. API Service (`app/services/squarespace_api_service.rb`)

Created `SquarespaceApiService` to handle all Squarespace API interactions:

**Core Methods:**
- `exchange_code_for_token(code, redirect_uri)` - OAuth token exchange
- `get_site_info(access_token)` - Fetch site information
- `get_products(cursor:)` - List all products (paginated)
- `get_product(product_id)` - Get specific product
- `get_orders(modified_after:, modified_before:, cursor:)` - List orders
- `get_order(order_id)` - Get specific order
- `fulfill_order(order_id, fulfillment_data)` - Create fulfillment

**API Configuration:**
- Base URL: `https://api.squarespace.com`
- Token URL: `https://login.squarespace.com/api/1/login/oauth/provider/tokens`
- Uses HTTP gem (already in project)
- Proper headers: Authorization Bearer, User-Agent, Content-Type

**Error Handling:**
- Custom error classes: `SquarespaceApiError`, `SquarespaceAuthError`, `SquarespaceRateLimitError`
- Handles HTTP status codes: 200-299 (success), 401 (auth), 429 (rate limit), others (generic error)

### 4. Store Integration Concern (`app/models/concerns/squarespace_integration.rb`)

Updated the existing `SquarespaceIntegration` concern:

**New Methods:**
- `squarespace_api_client` - Returns configured API service instance
- `fetch_site_info!` - Fetches and updates store with latest site information

**Updated Methods:**
- `squarespace_admin_url` - Returns correct admin URL format
- `squarespace_commerce_url` - Returns commerce section URL
- `squarespace_orders_url` - Returns orders page URL
- `squarespace_site_url` - Returns public site URL

**Validations:**
- Requires `squarespace_domain` when platform is squarespace
- Ensures `squarespace_domain` uniqueness
- Clears non-Squarespace fields when platform changes

### 5. UI Updates (`app/views/connections/dashboard/index.html.erb`)

**Connected Stores Section:**
- Updated to show Squarespace logo for Squarespace stores
- Uses `store.display_identifier` to show appropriate domain/identifier
- Platform detection via `store.shopify?` and `store.squarespace?`

**Available Platforms Section:**
- Changed Squarespace status from "Coming Soon" to "Available"
- Added "Connect Squarespace" button
- Shows count of connected Squarespace stores
- Links to `/connections/squarespace/connect`

### 6. Credentials

OAuth credentials stored in `config/application.yml`:
```yaml
SQUARESPACE_CLIENT_ID: QLB64wfqpm68SzmMZOGWqnn5djdchb5X
SQUARESPACE_SECRET: 98IveZ72C0yp6UWq7la120huxXns+e5GJZP6EIMurIU=
```

Registered redirect URIs:
- `http://localhost:3000` (development)
- `https://connect.framefox.com` (production)

## OAuth Flow

1. User clicks "Connect Squarespace" button
2. Redirected to `/connections/squarespace/connect`
3. Auth controller generates state token and redirects to Squarespace
4. User authorizes app on Squarespace's site
5. Squarespace redirects to `/connections/squarespace/callback?code=XXX&state=YYY`
6. Controller verifies state, exchanges code for token
7. Controller fetches site info using token
8. Controller creates/updates Store record associated with current user
9. User redirected to store management page

## Database Schema

The Store model already had the required fields:
- `squarespace_domain` (string, unique) - Site identifier
- `squarespace_token` (string) - OAuth access token
- `platform` (enum) - Includes "squarespace" option

## User Context

Uses `RequestStore[:current_user]` (set by `UserContextMiddleware`) to associate stores with the authenticated user during OAuth callback, matching the Shopify integration pattern.

## Testing Guide

### Manual Testing Steps

1. **Start the Rails server:**
   ```bash
   bin/dev
   ```

2. **Login to Framefox Connect:**
   - Navigate to `http://localhost:3000`
   - Login with your user account

3. **Navigate to Connections:**
   - Go to `http://localhost:3000/connections`
   - Verify "Connect Squarespace" button is visible

4. **Initiate OAuth Flow:**
   - Click "Connect Squarespace" button
   - Verify redirect to Squarespace login page
   - Check URL contains correct parameters (client_id, redirect_uri, scope, state)

5. **Authorize Application:**
   - Login to your Squarespace test site
   - Authorize the application
   - Verify redirect back to localhost:3000/connections/squarespace/callback

6. **Verify Store Creation:**
   - Check that you're redirected to the store page
   - Verify store appears in connections dashboard
   - Check store shows correct name and domain
   - Verify Squarespace logo displays correctly

7. **Test Disconnect:**
   - Go to store settings
   - Click disconnect
   - Verify store is removed from database

### Console Testing

Test API service directly in Rails console:

```ruby
# Get a store
store = Store.squarespace_stores.first

# Test API client
client = store.squarespace_api_client

# Fetch site info
site_info = client.get_site_info
puts site_info

# Fetch products
products = client.get_products
puts products

# Fetch orders
orders = client.get_orders
puts orders
```

## API Permissions Required

The following Squarespace Commerce API scopes are requested:
- `website.orders` - Read AND write order information (includes fulfillment management)
- `website.products` - Read AND write product information
- `website.inventory` - Read AND write inventory levels

**Note:** Squarespace uses base scopes for full access. To request read-only access, append `.read` to the scope (e.g., `website.orders.read`).

## Future Enhancements

Ready for implementation once OAuth is tested:
1. Product sync from Squarespace to Framefox
2. Order webhook integration
3. Automatic fulfillment creation
4. Inventory management

## References

- [Squarespace Commerce APIs Authentication](https://developers.squarespace.com/commerce-apis/authentication-and-permissions)
- [Squarespace Making Requests Guide](https://developers.squarespace.com/commerce-apis/making-requests)
- [Squarespace Site Info API](https://developers.squarespace.com/commerce-apis/retrieve-basic-site-info)
- [Squarespace Products API](https://developers.squarespace.com/commerce-apis/products-api/overview)
- [Squarespace Orders API](https://developers.squarespace.com/commerce-apis/orders-api/overview)

## Files Created

- `app/controllers/connections/squarespace/auth_controller.rb`
- `app/services/squarespace_api_service.rb`
- `guides/SQUARESPACE_OAUTH_IMPLEMENTATION.md`

## Files Modified

- `config/routes.rb` - Added Squarespace OAuth routes
- `app/models/concerns/squarespace_integration.rb` - Updated with API client methods
- `app/views/connections/dashboard/index.html.erb` - Added Connect button and store display

## Notes

- Uses the HTTP gem (already in project) instead of HTTParty
- Follows same pattern as Shopify integration for consistency
- Store model's `connected?` method already handles Squarespace platform
- Dynamic redirect URI building supports both development and production URLs
- CSRF protection via state parameter
- Comprehensive error handling with custom exception classes
- **Development Only:** Squarespace integration is restricted to development environment until fully tested
  - UI: Squarespace card only shows in development (`Rails.env.development?`)
  - Controller: `before_action :ensure_development_environment` blocks production access

