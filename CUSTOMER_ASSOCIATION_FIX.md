# Customer Association Fix

## Problem
When a Shopify store was authenticated via OAuth, it wasn't being associated with the logged-in customer.

## Root Cause
1. The ShopifyApp OAuth callback doesn't go through our `Connections::ApplicationController`, so the `Thread.current[:current_shopify_customer_id]` wasn't being set when `Store.store(session)` was called.
2. The middleware was passing through the external Shopify ID instead of the database ID.
3. Impersonation mode uses different session keys that need special handling.

## Solution Implemented

### 1. Rack Middleware for Customer Context
Created `/app/middleware/customer_context_middleware.rb` that runs on every request to set the customer context:

```ruby
class CustomerContextMiddleware
  def call(env)
    session = env["rack.session"] || {}

    # Priority: impersonated_customer_id (database ID) > lookup by external_shopify_id
    if session[:impersonating] && session[:impersonated_customer_id]
      # When impersonating, use the database ID directly
      Thread.current[:current_shopify_customer_id] = session[:impersonated_customer_id]
    elsif session[:shopify_customer_id]
      # When not impersonating, lookup customer by external ID to get database ID
      customer = ShopifyCustomer.find_by(external_shopify_id: session[:shopify_customer_id])
      Thread.current[:current_shopify_customer_id] = customer&.id
    end

    @app.call(env)
  ensure
    Thread.current[:current_shopify_customer_id] = nil
  end
end
```

**Key Features:**
- Handles impersonation mode by checking `session[:impersonating]`
- Converts external Shopify ID to database ID
- Works for all requests including ShopifyApp OAuth callbacks
- Always cleans up thread variable after request

### 2. Admin Interface for Manual Assignment
Added the ability for admins to manually assign stores to customers:

**New Routes:**
- `GET /admin/stores/:id/edit` - Edit store form
- `PATCH /admin/stores/:id` - Update store

**Features:**
- Shows warning badge for stores without a customer
- Displays current customer assignment in store list
- Dropdown to select and assign customers
- Visual indicators for unassigned stores

### 3. Fixed Store Association
Corrected the Store model association to use the database ID:

```ruby
belongs_to :shopify_customer, 
           foreign_key: :shopify_customer_id, 
           optional: true
```

The `shopify_customer_id` column in the stores table now correctly references the `id` column (primary key) in the shopify_customers table.

## How It Works Now

### Automatic Assignment (OAuth Flow - Normal Mode)
1. Customer logs in via handoff → `session[:shopify_customer_id]` is set (external Shopify ID)
2. Customer clicks "Connect Shopify Store"
3. ShopifyApp OAuth redirects to Shopify
4. Shopify redirects back to our callback
5. Middleware reads `session[:shopify_customer_id]`, looks up customer, sets database ID in `Thread.current`
6. ShopifyApp calls `Store.store(session)`
7. Store.store reads `Thread.current[:current_shopify_customer_id]` (database ID) and associates store
8. Store is now linked to the customer!

### Automatic Assignment (OAuth Flow - Impersonation Mode)
1. Admin impersonates customer → `session[:impersonated_customer_id]` is set (database ID)
2. Admin (as customer) clicks "Connect Shopify Store"
3. ShopifyApp OAuth redirects to Shopify
4. Shopify redirects back to our callback
5. Middleware detects impersonation, uses `session[:impersonated_customer_id]` directly (database ID)
6. ShopifyApp calls `Store.store(session)`
7. Store.store reads `Thread.current[:current_shopify_customer_id]` and associates store
8. Store is now linked to the impersonated customer!

### Manual Assignment (Admin)
1. Admin visits `/admin/stores`
2. Sees stores with yellow "No Customer" badge
3. Clicks "Edit" on the store
4. Selects customer from dropdown
5. Saves → Store is now associated!

## Testing the Fix

### For New Store Connections
1. Log in as a customer via handoff: `/auth/handoff?token=XXX`
2. Connect a new Shopify store
3. Verify the store appears in `/admin/stores` with customer name
4. Verify customer can see the store in their dashboard

### For Existing Stores
1. Visit `/admin/stores`
2. Find store with "No Customer" badge
3. Click "Edit"
4. Select customer from dropdown
5. Click "Save Changes"
6. Verify store now shows customer name in list

## Files Modified
- `/app/controllers/shopify_app/callback_controller.rb` (new)
- `/app/controllers/admin/stores_controller.rb` (added edit, update actions)
- `/app/models/store.rb` (fixed association)
- `/app/views/admin/stores/index.html.erb` (added customer display, badges, edit button)
- `/app/views/admin/stores/edit.html.erb` (new - edit form)
- `/config/routes.rb` (added edit, update routes)

## Next Steps
For any stores that were created before this fix, admins should:
1. Visit `/admin/stores`
2. Identify stores with "No Customer" badge
3. Click "Edit" and assign them to the appropriate customer

