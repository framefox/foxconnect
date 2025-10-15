# User Model Refactor - Implementation Complete

## Overview

Successfully refactored the application to introduce a User model as the root-level entity. Users are now the primary authentication entity and own ShopifyCustomers and Stores.

## Database Changes

### Migrations Created

1. **CreateUsers** (`20251014234117_create_users.rb`)

   - Created users table with email (unique, not null), first_name, last_name
   - Added unique index on email

2. **AddUserIdToShopifyCustomers** (`20251014234137_add_user_id_to_shopify_customers.rb`)

   - Added user_id reference to shopify_customers table

3. **MigrateShopifyCustomersToUsers** (`20251014234154_migrate_shopify_customers_to_users.rb`)

   - Created a User for each existing ShopifyCustomer
   - Linked each ShopifyCustomer to their new User
   - Made user_id non-nullable

4. **RemoveFieldsFromShopifyCustomers** (`20251014234212_remove_fields_from_shopify_customers.rb`)

   - Removed email, first_name, last_name from shopify_customers (now delegated to User)

5. **MigrateStoresToUsers** (`20251014234223_migrate_stores_to_users.rb`)
   - Added user_id to stores
   - Migrated existing store associations from shopify_customer_id to user_id
   - Removed shopify_customer_id column

## Model Changes

### User Model (NEW)

- **Location:** `app/models/user.rb`
- **Associations:**
  - `has_many :shopify_customers`
  - `has_many :stores`
- **Validations:** email presence, uniqueness, and format
- **Methods:** `full_name` helper

### ShopifyCustomer Model (UPDATED)

- **Location:** `app/models/shopify_customer.rb`
- **Changes:**
  - Now belongs_to :user
  - Removed email/name fields and validations
  - Added delegations to user: `email`, `first_name`, `last_name`, `full_name`
  - Removed has_many :stores association (stores now belong to users)

### Store Model (UPDATED)

- **Location:** `app/models/store.rb`
- **Changes:**
  - Changed from `belongs_to :shopify_customer` to `belongs_to :user`
  - Updated Store.store method to use `Thread.current[:current_user_id]`

## Admin Interface

### New Admin::UsersController

- **Location:** `app/controllers/admin/users_controller.rb`
- **Actions:** index, show, new, create, edit, update, destroy, impersonate, stop_impersonating
- **Features:**
  - Full CRUD operations for users
  - User impersonation (moved from shopify_customers_controller)
  - Pagination with Pagy

### Admin User Views

Created in `app/views/admin/users/`:

- `index.html.erb` - List all users with stores/shopify_customers count
- `show.html.erb` - Display user details, linked Shopify accounts, stores, impersonate button
- `new.html.erb` - Create new user form
- `edit.html.erb` - Edit user form
- `_form.html.erb` - Shared form partial

### Updated Admin::StoresController

- **Location:** `app/controllers/admin/stores_controller.rb`
- **Changes:**
  - Updated to use `@users` instead of `@customers`
  - Changed params to accept `user_id` instead of `shopify_customer_id`

### Updated Admin Store Views

- `edit.html.erb` - Changed customer assignment to user assignment
- `index.html.erb` - Display user instead of shopify_customer

## Authentication Refactor

### AuthController (UPDATED)

- **Location:** `app/controllers/auth_controller.rb`
- **Changes:**
  - `handoff` method now creates/finds User first, then creates/finds ShopifyCustomer
  - Stores `user_id` in session instead of `shopify_customer_id`
  - New method: `find_or_create_user_and_shopify_customer`

### ApplicationController (UPDATED)

- **Location:** `app/controllers/application_controller.rb`
- **New Methods:**
  - `current_user` - find User by session[:user_id]
  - `user_signed_in?` - check if user is signed in
  - `authenticate_user!` - require user authentication
  - `impersonated_user` - get impersonated user
- **Backwards Compatibility:**
  - `current_customer` now aliases `current_user`
  - `customer_signed_in?` now aliases `user_signed_in?`
  - `authenticate_customer!` now calls `authenticate_user!`

### Middleware (REPLACED)

- **Old:** `app/middleware/customer_context_middleware.rb` (DELETED)
- **New:** `app/middleware/user_context_middleware.rb`
- **Changes:**
  - Sets `Thread.current[:current_user_id]` instead of `:current_shopify_customer_id`
  - Uses `session[:user_id]` and `session[:impersonated_user_id]`
- **Updated:** `config/application.rb` to use new middleware

## Controller Updates

All controllers updated to use `current_user` instead of `current_customer` and `user_id` instead of `shopify_customer_id`:

### Connection Controllers

- `connections/application_controller.rb` - authenticate_user!, current_user
- `connections/dashboard_controller.rb` - current_user.stores
- `connections/stores_controller.rb` - current_user.stores.find
- `connections/stores/product_variants_controller.rb` - actor: current_user

### Customer-Facing Controllers

- `orders_controller.rb` - authenticate_user!, user_id in queries
- `order_items_controller.rb` - authenticate_user!, actor: current_user
- `import_orders_controller.rb` - authenticate_user!, current_user.stores
- `variant_mappings_controller.rb` - authenticate_user!, user_id in queries

## View Updates

### Layout & Shared Views

- **`layouts/application.html.erb`:**

  - Changed impersonation banner to use `impersonated_user`
  - Updated stop impersonating path to `stop_impersonating_admin_users_path`

- **`shared/_sidebar.html.erb`:**
  - Updated stop impersonating path to use users path
  - Still uses `current_customer` (backwards compatible alias)

## Routes

### New Routes Added

```ruby
resources :users do
  member do
    post :impersonate
  end
  collection do
    delete :stop_impersonating
  end
end
```

### Existing Routes Kept

- Shopify customers routes remain for CRUD operations (no impersonation)
- Impersonation routes only exist for Users

## Key Design Decisions

1. **One User per ShopifyCustomer Initially:** The migration creates one User for each existing ShopifyCustomer, even if emails are duplicates. This preserves all data.

2. **ShopifyCustomer Delegation:** Instead of removing ShopifyCustomer fields entirely, we delegate to User. This maintains the model's interface while centralizing data.

3. **Backwards Compatibility:** Added helper methods (`current_customer`, `customer_signed_in?`) that alias to the new user methods, reducing breaking changes.

4. **User-Owned Stores:** Stores now belong to Users directly, not ShopifyCustomers. A User can have multiple ShopifyCustomers (different Shopify accounts).

5. **Authentication by User:** Session stores `user_id` instead of `shopify_customer_id`. The User is the authenticated entity.

6. **Impersonation at User Level:** Admins now impersonate Users, not ShopifyCustomers. This aligns with the new hierarchy.

## Data Flow

### Authentication Flow

1. User logs in via Shopify JWT handoff
2. `AuthController#handoff` receives JWT payload
3. Find or create User by email
4. Find or create ShopifyCustomer by external_shopify_id, linked to User
5. Store `user_id` in session

### Store Association Flow

1. User connects a Shopify store via OAuth
2. `UserContextMiddleware` sets `Thread.current[:current_user_id]`
3. `Store.store` method associates store with `user_id` from Thread.current
4. Store is now owned by the User

### Impersonation Flow

1. Admin clicks "Impersonate" on User show page
2. `Admin::UsersController#impersonate` sets session vars:
   - `session[:impersonating] = true`
   - `session[:impersonated_user_id] = user.id`
   - `session[:user_id] = user.id`
3. Middleware picks up impersonated_user_id
4. All requests execute as that User
5. Admin clicks "Stop Impersonating"
6. Session vars cleared, returns to admin view

## Testing Recommendations

1. **User CRUD:** Create, read, update, delete users in admin
2. **Authentication:** Log in via JWT handoff, verify session has user_id
3. **Store Association:** Connect a store, verify it's associated with correct user
4. **Impersonation:** Impersonate a user, verify all actions execute as that user
5. **Backwards Compatibility:** Verify `current_customer` still works in views
6. **Data Integrity:** Verify all existing stores migrated to correct users
7. **ShopifyCustomer Delegation:** Verify email/name still accessible via ShopifyCustomer

## Future Enhancements

1. **Admin Authentication:** Add Devise gem for separate admin authentication
2. **User Merge:** Add ability to merge duplicate users (same email)
3. **Multi-tenancy:** Users could belong to organizations/companies
4. **Permissions:** Add role-based access control for users

## Files Changed

### Models

- `app/models/user.rb` (NEW)
- `app/models/shopify_customer.rb` (UPDATED)
- `app/models/store.rb` (UPDATED)

### Controllers

- `app/controllers/application_controller.rb` (UPDATED)
- `app/controllers/auth_controller.rb` (UPDATED)
- `app/controllers/admin/users_controller.rb` (NEW)
- `app/controllers/admin/stores_controller.rb` (UPDATED)
- `app/controllers/connections/application_controller.rb` (UPDATED)
- `app/controllers/connections/dashboard_controller.rb` (UPDATED)
- `app/controllers/connections/stores_controller.rb` (UPDATED)
- `app/controllers/connections/stores/product_variants_controller.rb` (UPDATED)
- `app/controllers/orders_controller.rb` (UPDATED)
- `app/controllers/order_items_controller.rb` (UPDATED)
- `app/controllers/import_orders_controller.rb` (UPDATED)
- `app/controllers/variant_mappings_controller.rb` (UPDATED)

### Views

- `app/views/admin/users/` (NEW - 5 files)
- `app/views/admin/stores/edit.html.erb` (UPDATED)
- `app/views/admin/stores/index.html.erb` (UPDATED)
- `app/views/layouts/application.html.erb` (UPDATED)
- `app/views/shared/_sidebar.html.erb` (UPDATED)

### Middleware

- `app/middleware/user_context_middleware.rb` (NEW)
- `app/middleware/customer_context_middleware.rb` (DELETED)

### Configuration

- `config/routes.rb` (UPDATED)
- `config/application.rb` (UPDATED)

### Migrations

- 5 new migration files created and executed successfully

## Additional Fixes (Post-Implementation)

### Admin::ShopifyCustomersController Updates

After initial deployment, the ShopifyCustomers admin controller was updated to work with the new User model:

1. **show action** - Now accesses stores through `@customer.user.stores` instead of `@customer.stores`
2. **customer_params** - Updated to accept `user_id` instead of `email`, `first_name`, `last_name`
3. **Removed impersonation** - Impersonation is now only available at the User level, not ShopifyCustomer level

### Admin ShopifyCustomer Views Updates

1. **\_form.html.erb** - Replaced email/name fields with a User selector dropdown
2. **show.html.erb** - Added "Linked User" section showing the associated User with a link to the User admin page, removed impersonate button (impersonation is now only on Users)

These updates ensure the ShopifyCustomers admin interface works seamlessly with the new User-centric architecture.

## Summary

This refactor successfully introduces the User model as the primary entity in the system. Users now own both ShopifyCustomers (platform-specific identities) and Stores (platform connections). The authentication system has been updated to work with Users, and the admin interface now provides full CRUD operations and impersonation at the User level. All existing functionality has been preserved through backwards-compatible methods and careful data migration. The ShopifyCustomers admin interface has been updated to work with the new User model, allowing admins to manage the relationship between Users and their Shopify identities.
