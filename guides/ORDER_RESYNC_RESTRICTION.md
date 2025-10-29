# Order Resync Restriction and Email Action Update

## Overview

This implementation includes two key changes:

1. Restricted the "Resync from Shopify" functionality to only be available when orders are in Draft status
2. Moved the "Resend Email Confirmation" action from user-facing interface to admin-only

These changes prevent potential data conflicts and ensure consistency when orders have been submitted to production, while keeping administrative email controls within the admin interface.

## Changes Made

### 1. Resync Restriction

#### Controllers

**`app/controllers/orders_controller.rb`**

- Added guard clause in `resync` action to check if order is in draft state
- Returns error message if resync attempted on non-draft order
- Error message: "Can only resync orders in Draft status."

**`app/controllers/admin/orders_controller.rb`**

- Applied same draft-only restriction in admin controller
- Maintains consistency across user and admin interfaces

#### Views

**`app/views/orders/show.html.erb`**

- Wrapped resync link in `<% if @order.draft? %>` conditional
- Resync option now only appears in Actions dropdown for draft orders

**`app/views/admin/orders/show.html.erb`**

- Applied same conditional display logic
- Updated separator logic to only show when resync is visible

### 2. Resend Email Action - Admin Only

#### Controllers

**`app/controllers/orders_controller.rb`**

- Removed `resend_email` action (no longer available to regular users)
- Removed from `before_action :set_order` list

**`app/controllers/admin/orders_controller.rb`**

- Added `resend_email` action for admin use
- Checks for user email availability before sending
- Sends order confirmation email to store owner

#### Views

**`app/views/orders/show.html.erb`**

- Removed "Resend Email Confirmation" option from Actions dropdown

**`app/views/admin/orders/show.html.erb`**

- Added "Resend Email Confirmation" option to admin Actions dropdown
- Uses SVG icon for consistency

#### Routes

**`config/routes.rb`**

- Removed `post :resend_email` from user-facing orders routes
- Added `post :resend_email` to admin orders routes

## Business Logic

### Why Draft Only for Resync?

Once an order is submitted to production:

- It has been sent to the production system
- Line items may have been fulfilled
- Resyncing could override production data
- Payment status may have been captured

### Why Admin Only for Resend Email?

The resend email confirmation functionality is an administrative action that:

- Should be controlled by admin users
- Prevents regular users from spamming store owners with emails
- Keeps administrative email controls centralized in admin interface

### Order States

Based on the Order model's AASM state machine:

- **draft** - Resync allowed ✓
- **in_production** - Resync blocked ✗
- **fulfilled** - Resync blocked ✗
- **cancelled** - Resync blocked ✗

## User Experience

### Draft Orders (Resync)

- Resync option appears in Actions dropdown
- Confirmation dialog before resyncing
- Activity logged when resync occurs

### Non-Draft Orders (Resync)

- Resync option hidden from UI
- Attempting direct URL access returns error message
- User-friendly error: "Can only resync orders in Draft status."

### Email Resend

- **User Interface**: No resend email option available
- **Admin Interface**: Resend email option available in Actions dropdown for all orders

## Technical Details

### Resync Guard Implementation

```ruby
def resync
  unless @order.draft?
    redirect_to order_path(@order), alert: "Can only resync orders in Draft status."
    return
  end

  # ... resync logic
end
```

### Resync View Conditional

```erb
<% if @order.draft? %>
  <%= link_to resync_order_path(@order), ... %>
<% end %>
```

### Admin Email Action

```ruby
def resend_email
  if @order.store.user.email.blank?
    redirect_to admin_order_path(@order), alert: "Cannot send email: No user email address on file."
    return
  end

  begin
    OrderMailer.with(order_id: @order.id).draft_imported.deliver_now
    redirect_to admin_order_path(@order), notice: "Email confirmation sent to #{@order.store.user.email}."
  rescue => e
    Rails.logger.error "Error sending email for order #{@order.id}: #{e.message}"
    redirect_to admin_order_path(@order), alert: "Failed to send email: #{e.message}"
  end
end
```

## Testing Considerations

### Resync Functionality

1. Create a draft order - resync should be available
2. Submit order to production - resync should disappear
3. Attempt direct URL access to resync on non-draft order - should see error message
4. Reopen cancelled order - resync should appear again (returns to draft)

### Email Resend Functionality

1. View order in user interface - resend email option should not appear
2. View same order in admin interface - resend email option should appear
3. Click resend email in admin - should send email to store owner
4. Attempt direct URL access to resend_email from user context - should get routing error

## Related Files

- `app/models/order.rb` - AASM state machine definition
- `app/services/import_order_service.rb` - Resync implementation
- `app/services/order_activity_service.rb` - Activity logging
- `app/mailers/order_mailer.rb` - Email sending functionality

## Date Implemented

October 29, 2025
