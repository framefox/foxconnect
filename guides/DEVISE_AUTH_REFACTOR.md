# Devise Authentication Refactor

## Summary

Refactored the authentication system to use Devise exclusively, removing the JWT handoff functionality and simplifying user context management using RequestStore instead of Thread-local variables.

## Changes Made

### 1. Updated UserContextMiddleware (`app/middleware/user_context_middleware.rb`)

**Before:**

- Looked for `session[:user_id]` which was never set by Devise
- Used `Thread.current[:current_user_id]` which is not thread-safe
- This caused the Shopify OAuth callback to fail because the user context was never set

**After:**

- Now properly integrates with Devise/Warden authentication
- Gets the authenticated user directly from Warden: `env["warden"].user`
- Uses `RequestStore[:current_user]` instead of Thread-local variables (thread-safe, request-scoped)
- Handles both normal authentication and admin impersonation
- This ensures the `Store.store(session)` method can associate stores with the correct user

### 2. Removed JWT Handoff System

**Files Removed:**

- `app/services/jwt_token_service.rb` - No longer needed

**Files Modified:**

- `app/controllers/auth_controller.rb` - Removed `handoff` action and JWT logic, kept only `logout`
- `config/routes.rb` - Removed `get "auth/handoff"` route
- `app/controllers/connections/shopify/auth_controller.rb` - Changed `current_customer` to `current_user`

**Files Kept:**

- `app/models/shopify_customer.rb` - Still used for admin functionality and company management
- `app/controllers/admin/shopify_customers_controller.rb` - Still needed for admin interface

### 3. Authentication Flow

**Current Flow:**

1. User logs in via Devise (email/password)
2. User navigates to `/connections` and clicks "Connect Shopify"
3. Redirected to Shopify OAuth
4. Shopify redirects back to `/connections/auth/shopify/callback`
5. ShopifyApp engine processes the callback
6. Calls `Store.store(session)` to save the store
7. `UserContextMiddleware` has already set `Thread.current[:current_user_id]` from Warden
8. Store is associated with the current user
9. User is redirected to connections dashboard

## How the Fix Works

### The Problem

When a user returned from Shopify OAuth, the `Store.store(session)` method tried to associate the store with a user using `Thread.current[:current_user_id]`, but this was always `nil` because:

- The middleware was looking for `session[:user_id]`
- Devise doesn't set this - it uses Warden's internal session management

### The Solution

The middleware now:

1. Gets the Warden instance from `env["warden"]`
2. Gets the authenticated user object: `warden.user` (uses default :user scope)
3. Stores the user in RequestStore: `RequestStore[:current_user] = user`
4. Includes error handling to prevent breaking requests if Warden fails

The `Store.store(session)` method accesses this via `RequestStore[:current_user]&.id`.

**Why RequestStore instead of Thread.current?**

- RequestStore is designed for request-scoped data
- Automatically clears data at the end of each request (no memory leaks)
- Thread-safe and works correctly with concurrent requests
- More idiomatic Rails pattern

This happens **before** the ShopifyApp callback controller runs, ensuring the user context is available when `Store.store(session)` is called.

## Testing

To test the Shopify OAuth flow:

1. Ensure you're logged in via Devise
2. Navigate to `/connections`
3. Click "Connect Shopify"
4. Complete the Shopify OAuth flow
5. Verify that:
   - The store is created successfully
   - The store is associated with your user account
   - You're redirected back to `/connections` without errors

## Backwards Compatibility

The following helper methods remain for backwards compatibility:

- `current_customer` → `current_user`
- `customer_signed_in?` → `user_signed_in?`
- `authenticate_customer!` → `authenticate_user!`

These are defined in `ApplicationController` and can be gradually migrated over time.

## Technical Details

### Why We Need Middleware

You might wonder: "Why not just use `current_user` from the controller?"

The answer is that the ShopifyApp gem's callback controller (which processes the OAuth callback) calls `Store.store(session)` - a **class method** on the Store model. Class methods don't have access to controller helper methods like `current_user`.

We could override the entire ShopifyApp callback flow, but that's fragile and complex. Instead, we use middleware to make the current user available via RequestStore, which can be accessed from anywhere (controllers, models, services).

### RequestStore Benefits

- **Request-scoped**: Data is automatically scoped to the current request
- **Thread-safe**: Works correctly with concurrent requests
- **Auto-cleanup**: No need for `ensure` blocks, RequestStore clears itself
- **Rails idiom**: Standard pattern for making request data available to models

## Notes

- The `ShopifyCustomer` model and admin functionality were retained as they serve a different purpose (managing Shopify customer records and company associations)
- The middleware handles both normal authentication and admin impersonation
- RequestStore automatically cleans up after each request - no memory leaks
- Added `request_store` gem to Gemfile
