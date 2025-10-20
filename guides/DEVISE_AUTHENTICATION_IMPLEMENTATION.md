# Devise Authentication Implementation

## Overview

Successfully integrated Devise authentication to support dual authentication modes:

- **Password-based login** for admin users
- **JWT token handoff** (passwordless) for regular users from main Framefox app

## What Was Implemented

### 1. Dependencies Added

- `devise ~> 4.9` - Authentication framework
- `bcrypt ~> 3.1.7` - Password encryption

### 2. Database Schema Changes

**Migration: AddDeviseToUsers**

- `encrypted_password` (string, default: "", not null)
- `reset_password_token` (string, unique index)
- `reset_password_sent_at` (datetime)
- `remember_created_at` (datetime)
- `sign_in_count` (integer, default: 0, not null)
- `current_sign_in_at` (datetime)
- `last_sign_in_at` (datetime)
- `current_sign_in_ip` (string)
- `last_sign_in_ip` (string)

**Migration: AddAdminToUsers**

- `admin` (boolean, default: false, not null)

### 3. User Model Updates

**File:** `app/models/user.rb`

Added Devise modules:

- `:database_authenticatable` - Password-based login
- `:recoverable` - Password reset functionality
- `:rememberable` - "Remember me" cookie functionality
- `:trackable` - Sign-in tracking (timestamps, IPs)
- `:validatable` - Email and password validations

**Custom Methods:**

```ruby
# Makes password optional for non-admin users (JWT handoff users)
def password_required?
  admin? && (encrypted_password.blank? || password.present?)
end

# Prevents Devise reconfirmation for JWT users
def email_changed?
  false
end

# Convenience method for checking admin status
def admin?
  admin == true
end
```

### 4. Authentication Controllers

**ApplicationController** (`app/controllers/application_controller.rb`)

- Removed custom auth helpers (now provided by Devise):
  - `current_user`
  - `user_signed_in?`
  - `authenticate_user!`
- Kept impersonation helpers
- Kept backwards compatibility helpers

**AuthController** (`app/controllers/auth_controller.rb`)

- Updated `handoff` action to use `sign_in(user)` instead of manual session setting
- Updated `logout` action to use `sign_out(current_user)`
- JWT handoff flow remains unchanged

**Admin::ApplicationController** (`app/controllers/admin/application_controller.rb`)

- Removed `ShopifyApp::LoginProtection`
- Added `before_action :authenticate_user!` (Devise)
- Added `before_action :require_admin!`
- Implemented `require_admin!` method to check admin status

### 5. Routes and Views

**Routes** (`config/routes.rb`)

- Added Devise routes (shared by admins and customers): `devise_for :users`
- Login URL: `/login`
- Logout URL: `/logout`
- After sign-in, users are redirected based on role:
  - Admin users → `/admin` (admin dashboard)
  - Regular users → `/` (root/customer dashboard)

**Login View** (`app/views/devise/sessions/new.html.erb`)

- Styled to match admin interface
- Centered layout with clean design
- Email and password fields
- Remember me checkbox
- Forgot password link

**Password Reset Views**

- `app/views/devise/passwords/new.html.erb` - Request reset
- `app/views/devise/passwords/edit.html.erb` - Set new password
- Both styled to match admin interface

**Admin Layout** (`app/views/layouts/admin.html.erb`)

- Added logout button to admin header

### 6. Admin User Management

**Admin::UsersController** (`app/controllers/admin/users_controller.rb`)

- Added `admin`, `password`, `password_confirmation` to permitted params
- Updated `impersonate` to use Devise's `sign_in`
- Updated `stop_impersonating` to use Devise's `sign_out`

**User Form** (`app/views/admin/users/_form.html.erb`)

- Added password field
- Added password confirmation field
- Added admin checkbox
- Password fields show helper text for existing users

**User Views**

- `show.html.erb` - Displays admin status badge
- `index.html.erb` - Shows admin badge next to admin users

### 7. Seeds

**File:** `db/seeds.rb`

Added admin user creation:

```ruby
User.find_or_create_by(email: "admin@framefox.com") do |user|
  user.first_name = "Admin"
  user.last_name = "User"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.admin = true
end
```

### 8. Configuration

**Devise Initializer** (`config/initializers/devise.rb`)

- Set mailer sender to: `noreply@framefox.com`

**Development Environment** (`config/environments/development.rb`)

- Already configured with mailer defaults

## Authentication Flows

### Admin Login Flow

1. Admin navigates to `/login`
2. Enters email and password
3. Devise authenticates credentials
4. Admin redirected to `/admin` (admin dashboard)
5. Access protected by `authenticate_user!` + `require_admin!`

### Customer Login Flow

1. Customer navigates to `/login`
2. Enters email and password
3. Devise authenticates credentials
4. Customer redirected to `/` (root/customer dashboard)
5. Access protected by `authenticate_customer!` (alias for `authenticate_user!`)

### JWT Handoff Flow (Unchanged)

1. User clicks launch button in main Framefox app
2. Main app generates JWT token with user data
3. User redirected to `/auth/handoff?token=XXX`
4. Token validated and decoded
5. User found/created (passwordless)
6. `sign_in(user)` called (now using Devise)
7. User redirected to connections dashboard

## Security Features

### Admin Protection

- All admin routes require:
  1. User must be authenticated (`authenticate_user!`)
  2. User must have `admin: true` (`require_admin!`)

### Password Requirements

- Admin users: **Must have password**
- Regular users: **No password required** (JWT only)
- Enforced via `password_required?` override

### Session Management

- Devise handles all session management
- Tracking of sign-in timestamps and IPs
- Remember me functionality
- Password recovery via email

## Usage

### Creating Admin Users

Via Admin Interface:

1. Navigate to `/admin/users/new`
2. Fill in email, first name, last name
3. Set password and confirmation
4. Check "Admin User" checkbox
5. Click "Create User"

Via Rails Console:

```ruby
User.create!(
  email: "admin@example.com",
  first_name: "Admin",
  last_name: "User",
  password: "secure_password",
  password_confirmation: "secure_password",
  admin: true
)
```

### Creating Regular Users

Regular users are created automatically via JWT handoff. They don't need passwords.

### Promoting Users to Admin

1. Navigate to user's edit page in admin
2. Check "Admin User" checkbox
3. Set a password if they don't have one
4. Save

## Default Admin Credentials

**Email:** admin@framefox.com  
**Password:** password123

⚠️ **IMPORTANT:** Change this password in production!

## Testing

### Test Admin Login

1. Start Rails server: `rails s`
2. Navigate to: `http://localhost:3000/login`
3. Login with admin credentials
4. Verify redirect to `/admin` (admin dashboard)
5. Test logout functionality

### Test Customer Login

1. Navigate to: `http://localhost:3000/login`
2. Login with non-admin user credentials
3. Verify redirect to `/` (customer dashboard)
4. Test logout functionality

### Test JWT Handoff

1. Generate JWT token from main app
2. Navigate to: `/auth/handoff?token=XXX`
3. Verify user is created/found
4. Verify user is logged in
5. Verify access to connections dashboard

### Test Admin Protection

1. Create non-admin user
2. Try to access `/admin` routes
3. Verify redirect with "Access denied" message

## Backward Compatibility

- JWT handoff flow unchanged
- All existing users continue to work
- Existing sessions remain valid
- All helper methods still available

## Key Files Modified

### Models

- `app/models/user.rb`

### Controllers

- `app/controllers/application_controller.rb`
- `app/controllers/auth_controller.rb`
- `app/controllers/admin/application_controller.rb`
- `app/controllers/admin/users_controller.rb`

### Views

- `app/views/devise/sessions/new.html.erb`
- `app/views/devise/passwords/new.html.erb`
- `app/views/devise/passwords/edit.html.erb`
- `app/views/layouts/admin.html.erb`
- `app/views/admin/users/_form.html.erb`
- `app/views/admin/users/show.html.erb`
- `app/views/admin/users/index.html.erb`

### Configuration

- `config/routes.rb`
- `config/initializers/devise.rb`
- `db/seeds.rb`

### Migrations

- `db/migrate/XXXXXX_add_devise_to_users.rb`
- `db/migrate/XXXXXX_add_admin_to_users.rb`

## Future Enhancements

Potential improvements:

- Two-factor authentication for admin users
- Role-based permissions (beyond admin/user)
- Admin activity audit log
- Password complexity requirements
- Account lockout after failed attempts
- Session timeout configuration

## Troubleshooting

### "Email has already been taken"

- User already exists, use login instead of creating new

### "Password can't be blank" for non-admin

- Ensure user is not marked as admin
- Check `password_required?` method

### Can't access admin routes

- Verify user has `admin: true`
- Check you're logged in
- Verify `require_admin!` is working

### Password reset emails not sending

- Check mailer configuration
- In development, check Letter Opener
- Verify `action_mailer.default_url_options`

## Notes

- Devise provides many more modules (`:confirmable`, `:lockable`, etc.) that can be added if needed
- The implementation maintains full backward compatibility with JWT handoff
- Admin users can still be impersonated for testing
- All Devise helpers are available throughout the application
