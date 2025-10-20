# Customer Invite Feature

## Overview

Admins can now send invitation emails to customers from the admin panel. The invitation email welcomes users and asks them to set a password before they can login to Framefox Connect.

## How It Works

### Admin Workflow

1. Admin navigates to a user's show page in the admin panel (`/admin/users/:id`)
2. Admin clicks the "Send Invite" button (or "Resend Invite" if user already has a password)
3. System generates a Devise password reset token
4. System sends a custom welcome email to the user
5. Admin sees a success message confirming the email was sent

### Customer Workflow

1. Customer receives welcome email at their registered email address
2. Email includes a "Set My Password" button with a secure reset token
3. Customer clicks the link and is taken to Devise's password reset page
4. Customer sets their password
5. Customer can now login at `/login` with their email and new password

## Technical Implementation

### Routes

Added invite route to admin users:

```ruby
resources :users do
  member do
    post :impersonate
    post :invite  # New
  end
  # ...
end
```

URL: `POST /admin/users/:id/invite`

### Controller Action

**File:** `app/controllers/admin/users_controller.rb`

The `invite` action:

- Generates a Devise password reset token using `Devise.token_generator.generate`
- Stores the encrypted token in `user.reset_password_token`
- Sets `reset_password_sent_at` timestamp
- Sends custom welcome email via `UserMailer.welcome_invitation`
- Uses `deliver_later` for asynchronous email delivery
- Redirects back with success message

### UserMailer

**File:** `app/mailers/user_mailer.rb`

New mailer class with `welcome_invitation` method that:

- Accepts user and raw reset password token
- Generates reset password URL using `edit_user_password_url`
- Sends email to user's address
- Uses welcoming subject line

### Email Templates

**HTML Template:** `app/views/user_mailer/welcome_invitation.html.erb`

Features:

- Professional design matching Framefox branding
- "Welcome to Framefox Connect" heading
- Personalized greeting using user's first name
- Clear "Set My Password" call-to-action button
- Alternative plain URL link for accessibility
- All styles are inline for email client compatibility
- Works with Rails mailer layout (logo in header, footer with copyright)

**Text Template:** `app/views/user_mailer/welcome_invitation.text.erb`

Plain text version for email clients that don't support HTML.

### UI Integration

**File:** `app/views/admin/users/show.html.erb`

Added "Send Invite" button in the header actions area:

- Positioned before "Impersonate" and "Edit" buttons
- Blue color scheme (distinguishes from other actions)
- Envelope icon for visual clarity
- Dynamic text: "Send Invite" or "Resend Invite" based on password status
- Uses `button_to` for POST request

### Email Configuration

**File:** `app/mailers/application_mailer.rb`

Updated default from address to: `noreply@framefox.com`

**File:** `config/environments/development.rb`

Added asset host for mailer images:

```ruby
config.action_mailer.asset_host = "http://localhost:3000"
```

**File:** `config/environments/production.rb`

Added asset host for mailer images (update to your production domain):

```ruby
config.action_mailer.asset_host = "https://example.com"
```

**File:** `app/mailers/user_mailer.rb`

Attaches logo as inline attachment for reliable email delivery:

```ruby
attachments.inline['logo-connect-sm.png'] = File.read(Rails.root.join('app/assets/images/logo-connect-sm.png'))
```

**File:** `app/views/layouts/mailer.html.erb`

Displays logo in email header using inline attachment URL for cross-email-client compatibility

## Usage Examples

### Inviting a New Customer

1. Admin creates a new user in the admin panel
2. User is created without a password (since password is optional for JWT users)
3. Admin clicks "Send Invite" on the user's show page
4. Customer receives welcome email and sets their password
5. Customer can now login directly at `/login`

### Resending Invitation

1. Customer loses or doesn't receive initial invite
2. Admin navigates to user's show page
3. Admin clicks "Resend Invite"
4. New invitation email is sent with fresh reset token
5. Previous reset token is invalidated

## Security Features

### Token Generation

- Uses Devise's secure token generator
- Tokens are cryptographically random
- Encrypted token stored in database
- Raw token only sent via email (never stored)

### Token Expiration

- Devise automatically expires reset tokens after configured timeout
- Default: 6 hours (configurable in Devise initializer)
- Expired tokens cannot be used to set passwords

### Email Images

- Logo is attached as an inline attachment to ensure it displays correctly
- Uses `attachments.inline` which embeds the image in the email
- This approach works across all email clients (Gmail, Outlook, etc.)
- Alternative to absolute URLs which may be blocked by some clients

### Password Requirements

- Users must set password before they can login
- Password validation handled by Devise
- Minimum length and complexity requirements enforced

## Email Delivery

### Development

- Emails are intercepted by Letter Opener
- View emails in browser at `/letter_opener`
- No actual emails sent during development

### Production

- Emails delivered via configured SMTP/SendGrid/etc
- Asynchronous delivery using `deliver_later`
- Background job processing via Solid Queue

## Integration with Existing Authentication

### JWT Handoff Still Works

- Users created via JWT handoff don't need passwords initially
- They can be invited later to set a password for direct login
- JWT authentication remains unchanged

### Dual Login Methods

After setting password via invite, users can login via:

1. Direct login at `/login` with email/password
2. JWT handoff from main Framefox app (if applicable)

## Testing in Development

1. Start Rails server: `rails s`
2. Login to admin at `/login`
3. Navigate to `/admin/users`
4. Click on a user without a password
5. Click "Send Invite"
6. Check Letter Opener at `http://localhost:3000/letter_opener`
7. Click the "Set My Password" link in the email
8. Set a password
9. Test login at `/login`

## Files Modified

- `config/routes.rb`
- `app/controllers/admin/users_controller.rb`
- `app/views/admin/users/show.html.erb`
- `app/mailers/application_mailer.rb`
- `app/views/layouts/mailer.html.erb`
- `config/environments/development.rb`
- `config/environments/production.rb`

## Files Created

- `app/mailers/user_mailer.rb`
- `app/views/user_mailer/welcome_invitation.html.erb`
- `app/views/user_mailer/welcome_invitation.text.erb`

## Future Enhancements

Potential improvements:

- Track invitation status (invited, accepted, pending)
- Show last invitation sent timestamp on user show page
- Bulk invite functionality for multiple users
- Custom invitation message from admin
- Different invitation templates for different user types
- Automatic invitation on user creation (optional)
- Reminder emails for pending invitations

## Related Documentation

- [Devise Authentication Implementation](DEVISE_AUTHENTICATION_IMPLEMENTATION.md)
- Rails ActionMailer Guide
- Devise Documentation
