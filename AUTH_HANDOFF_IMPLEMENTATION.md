# Authentication Handoff Implementation

This document describes the JWT-based authentication handoff system implemented in FoxConnect.

## Overview

FoxConnect now supports cross-app authentication via JWT token handoff. Users are authenticated in the main app and can be seamlessly transferred to FoxConnect with a secure token.

## What Was Implemented

### 1. Database Changes

- Created `shopify_customers` table with:
  - `shopify_customer_id` (bigint, unique, not null) - Primary key from main app
  - `first_name` (string)
  - `last_name` (string)
  - `email` (string, not null)
  - `created_at`, `updated_at`

- Updated `stores` table:
  - Added `shopify_customer_id` (bigint) - Foreign key to shopify_customers

### 2. Models

**ShopifyCustomer** (`app/models/shopify_customer.rb`)
- Validations for shopify_customer_id and email
- `has_many :stores` relationship
- Helper method `full_name` for display

**Store** (`app/models/store.rb`)
- Added `belongs_to :shopify_customer` association
- Updated `self.store` method to auto-associate with current customer during OAuth

### 3. Authentication System

**JwtTokenService** (`app/services/jwt_token_service.rb`)
- Decodes JWT tokens using shared secret
- Handles expired/invalid tokens gracefully

**AuthController** (`app/controllers/auth_controller.rb`)
- `GET /auth/handoff?token=XXX` - Receives token, creates/finds customer, logs in
- `DELETE /auth/logout` - Logs out current customer

**ApplicationController**
- Added `current_customer`, `customer_signed_in?`, and `authenticate_customer!` helpers
- All available as view helpers

**Connections::ApplicationController**
- Requires customer authentication for all connections routes
- Automatically scopes stores to current customer
- Sets customer context for store creation during OAuth

### 4. Admin Interface

**Admin::ShopifyCustomersController** (`app/controllers/admin/shopify_customers_controller.rb`)
- Full CRUD operations for managing customers
- Routes: `/admin/shopify_customers`

**Admin Views** (`app/views/admin/shopify_customers/`)
- `index.html.erb` - List all customers with pagination
- `show.html.erb` - Customer details with associated stores
- `new.html.erb` - Create new customer
- `edit.html.erb` - Edit customer
- `_form.html.erb` - Shared form partial

### 5. Security Updates

All connections routes now:
- Require customer authentication
- Scope store queries to current customer
- Prevent unauthorized access to other customers' stores

## Configuration

### Environment Variables

Add to `config/application.yml`:

```yaml
JWT_SECRET_KEY: 'your-shared-secret-key-here'
```

**Important:** This key MUST be the same in both apps!

## Main App Requirements

The main app needs to implement the sending side of the handoff:

### 1. Install JWT Gem

```ruby
# Gemfile
gem 'jwt'
```

### 2. Add Same JWT Secret

```yaml
# config/application.yml (or equivalent)
JWT_SECRET_KEY: 'same-key-as-foxconnect'
```

### 3. Create Token Generation Service

```ruby
# app/services/foxconnect_handoff_service.rb
class FoxconnectHandoffService
  FOXCONNECT_URL = ENV['FOXCONNECT_URL'] # e.g., 'https://foxconnect.example.com'
  SECRET_KEY = ENV['JWT_SECRET_KEY']
  
  def self.generate_handoff_url(customer)
    token = JWT.encode(
      {
        shopify_customer_id: customer.id,
        email: customer.email,
        first_name: customer.first_name,
        last_name: customer.last_name,
        exp: 15.minutes.from_now.to_i
      },
      SECRET_KEY,
      'HS256'
    )
    
    "#{FOXCONNECT_URL}/auth/handoff?token=#{token}"
  end
end
```

### 4. Add Launch Button

In your customer dashboard or wherever you want the handoff:

```erb
<%= link_to "Launch FoxConnect", 
    FoxconnectHandoffService.generate_handoff_url(current_customer),
    class: "btn btn-primary",
    target: "_blank" %>
```

## Token Format

The JWT payload must include:

```json
{
  "shopify_customer_id": 12345,
  "email": "customer@example.com",
  "first_name": "John",
  "last_name": "Doe",
  "exp": 1234567890
}
```

- `shopify_customer_id` (required) - Unique customer ID from main app
- `email` (required) - Customer's email address
- `first_name` (optional) - Customer's first name
- `last_name` (optional) - Customer's last name
- `exp` (required) - Token expiration timestamp (recommended: 15 minutes)

## Security Considerations

1. **Token Expiration**: Tokens expire after 15 minutes to prevent replay attacks
2. **HTTPS Required**: Always use HTTPS in production for token transmission
3. **Shared Secret**: Keep JWT_SECRET_KEY secure and rotate periodically
4. **Customer Scoping**: All store operations are scoped to authenticated customer
5. **CSRF Protection**: Handoff endpoint skips CSRF for GET requests only

## Testing the Handoff

1. In main app, generate a token for a test customer
2. Visit: `http://localhost:3000/auth/handoff?token=YOUR_TOKEN`
3. Should be redirected to `/connections` with "Successfully logged in" message
4. Customer record should be created/updated in FoxConnect
5. Any stores connected will be associated with that customer

## Admin Access

Admins can manage customers at: `/admin/shopify_customers`

- View all customers
- Create/edit/delete customers manually
- View each customer's connected stores
- Search and filter customers (with pagination)

## Logout

Customers can logout at: `DELETE /auth/logout`

This clears the session and redirects to the root path.

