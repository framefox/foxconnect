# Authentication Handoff System - Implementation Summary

## Overview
Successfully implemented a JWT-based authentication handoff system that allows customers to seamlessly transfer from the main app to FoxConnect with secure token authentication.

## What Was Implemented

### 1. Dependencies
- ✅ Added `jwt` gem to Gemfile and installed
- ✅ Added `JWT_SECRET_KEY` to `config/application.yml`

### 2. Database Schema
**New Table: shopify_customers**
```ruby
- id (primary key)
- shopify_customer_id (bigint, unique, not null)
- first_name (string)
- last_name (string)
- email (string, not null)
- created_at, updated_at
```

**Updated Table: stores**
```ruby
- Added shopify_customer_id (bigint)
- Added index on shopify_customer_id
```

### 3. Models

**ShopifyCustomer** (`app/models/shopify_customer.rb`)
- Validates presence and uniqueness of shopify_customer_id
- Validates email format
- `has_many :stores` association
- Helper method `full_name` for display

**Store** (`app/models/store.rb`)
- Added `belongs_to :shopify_customer` (optional)
- Updated `self.store` method to auto-associate with current customer during OAuth
- Uses Thread.current to pass customer context

### 4. Services

**JwtTokenService** (`app/services/jwt_token_service.rb`)
- Decodes JWT tokens using shared secret key
- Gracefully handles expired and invalid tokens
- Logs errors for debugging

### 5. Controllers

**AuthController** (`app/controllers/auth_controller.rb`)
- `GET /auth/handoff?token=XXX` - Receives and validates token
- Creates or finds customer by shopify_customer_id
- Logs in customer and redirects to connections dashboard
- `DELETE /auth/logout` - Clears session and logs out

**ApplicationController** (`app/controllers/application_controller.rb`)
- Added `current_customer` helper
- Added `customer_signed_in?` helper
- Added `authenticate_customer!` before action method
- All helpers available in views

**Connections::ApplicationController** (`app/controllers/connections/application_controller.rb`)
- Requires customer authentication
- Sets customer context in Thread.current for store creation
- Cleans up thread variable after each request

**Connections::DashboardController** (`app/controllers/connections/dashboard_controller.rb`)
- Scoped stores to `current_customer.stores`

**Connections::StoresController** (`app/controllers/connections/stores_controller.rb`)
- Scoped store queries to `current_customer.stores`

**Connections::Shopify::AuthController** (`app/controllers/connections/shopify/auth_controller.rb`)
- Updated disconnect to scope by customer

**Admin::ShopifyCustomersController** (`app/controllers/admin/shopify_customers_controller.rb`)
- Full CRUD operations (index, show, new, create, edit, update, destroy)
- Pagination support using Pagy
- Proper error handling and flash messages

### 6. Views

**Admin Customer Views** (`app/views/admin/shopify_customers/`)
- `index.html.erb` - Lists all customers with pagination
- `show.html.erb` - Shows customer details and associated stores
- `new.html.erb` - Form to create new customer
- `edit.html.erb` - Form to edit existing customer
- `_form.html.erb` - Shared form partial with validation errors

**Layout Updates**
- Added "Customers" link to admin navigation (`app/views/layouts/admin.html.erb`)
- Added customer info panel to sidebar (`app/views/shared/_sidebar.html.erb`)
- Added "Sign Out" button in sidebar user section

### 7. Routes

**Public Routes**
```ruby
GET  /auth/handoff        # Handoff authentication endpoint
DELETE /auth/logout       # Logout endpoint
```

**Admin Routes**
```ruby
GET    /admin/shopify_customers           # List customers
POST   /admin/shopify_customers           # Create customer
GET    /admin/shopify_customers/new       # New customer form
GET    /admin/shopify_customers/:id/edit  # Edit customer form
GET    /admin/shopify_customers/:id       # Show customer
PATCH  /admin/shopify_customers/:id       # Update customer
DELETE /admin/shopify_customers/:id       # Delete customer
```

### 8. Security Enhancements
- All connection routes require customer authentication
- Store queries automatically scoped to current customer
- Prevents unauthorized access to other customers' stores
- Token expiration prevents replay attacks
- CSRF protection (skipped only for handoff endpoint)

## Configuration Required

### FoxConnect App (This App)
```yaml
# config/application.yml
JWT_SECRET_KEY: 'your-shared-secret-key-here'
```

### Main App (Reference Implementation)
```yaml
# config/application.yml
JWT_SECRET_KEY: 'same-key-as-foxconnect'
FOXCONNECT_URL: 'https://foxconnect.example.com'
```

## How It Works

### 1. Handoff Flow
```
Main App → Generate JWT Token → Redirect to FoxConnect → 
Validate Token → Create/Find Customer → Log In → Dashboard
```

### 2. Token Payload
```json
{
  "shopify_customer_id": 12345,
  "email": "customer@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "exp": 1234567890
}
```

### 3. Store Association
- When customer connects a Shopify store via OAuth
- Customer context is stored in Thread.current
- Store.store method reads Thread.current and associates store
- Ensures new stores are automatically linked to logged-in customer

## Testing the Implementation

### 1. Test Customer Creation via Handoff
```bash
# Generate a test token in Rails console (main app):
token = JWT.encode({
  shopify_customer_id: 12345,
  email: 'test@example.com',
  first_name: 'John',
  last_name: 'Doe',
  exp: 15.minutes.from_now.to_i
}, ENV['JWT_SECRET_KEY'], 'HS256')

# Visit in browser:
http://localhost:3000/auth/handoff?token=YOUR_TOKEN_HERE
```

### 2. Test Admin Interface
```
1. Visit /admin/shopify_customers
2. Create a new customer manually
3. View customer details
4. Edit customer information
5. Check associated stores
```

### 3. Test Customer Scoping
```
1. Log in as a customer via handoff
2. Connect a Shopify store
3. Verify store is associated with customer
4. Log out and log in as different customer
5. Verify you can't see other customer's stores
```

## Files Created
- `app/models/shopify_customer.rb`
- `app/services/jwt_token_service.rb`
- `app/controllers/auth_controller.rb`
- `app/controllers/admin/shopify_customers_controller.rb`
- `app/views/admin/shopify_customers/index.html.erb`
- `app/views/admin/shopify_customers/show.html.erb`
- `app/views/admin/shopify_customers/new.html.erb`
- `app/views/admin/shopify_customers/edit.html.erb`
- `app/views/admin/shopify_customers/_form.html.erb`
- `db/migrate/XXXXXX_create_shopify_customers.rb`
- `db/migrate/XXXXXX_add_shopify_customer_id_to_stores.rb`
- `AUTH_HANDOFF_IMPLEMENTATION.md` (documentation)
- `IMPLEMENTATION_SUMMARY.md` (this file)

## Files Modified
- `Gemfile` - Added jwt gem
- `config/application.yml` - Added JWT_SECRET_KEY
- `config/routes.rb` - Added auth and admin customer routes
- `app/models/store.rb` - Added customer association and auto-linking
- `app/controllers/application_controller.rb` - Added auth helpers
- `app/controllers/connections/application_controller.rb` - Added auth requirement
- `app/controllers/connections/dashboard_controller.rb` - Added customer scoping
- `app/controllers/connections/stores_controller.rb` - Added customer scoping
- `app/controllers/connections/shopify/auth_controller.rb` - Added customer scoping
- `app/views/layouts/admin.html.erb` - Added Customers nav link
- `app/views/shared/_sidebar.html.erb` - Added user info and logout button

## Next Steps for Main App

The main app team needs to:

1. Add `jwt` gem to Gemfile
2. Add same `JWT_SECRET_KEY` to config
3. Create token generation service (see AUTH_HANDOFF_IMPLEMENTATION.md)
4. Add "Launch FoxConnect" button in customer dashboard
5. Test the handoff flow end-to-end

## Security Notes

- Keep JWT_SECRET_KEY secure and rotate periodically
- Use HTTPS in production for all token transmission
- Token expiration is set to 15 minutes (configurable)
- Monitor failed authentication attempts in logs
- Consider adding rate limiting on handoff endpoint

## Support

For questions or issues with the authentication handoff:
1. Check AUTH_HANDOFF_IMPLEMENTATION.md for detailed setup
2. Review logs at `log/development.log` for JWT errors
3. Verify JWT_SECRET_KEY matches between both apps
4. Test token generation/decoding in Rails console

---

**Implementation Date**: October 13, 2025
**Status**: ✅ Complete and Ready for Testing

