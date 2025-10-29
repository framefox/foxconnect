# Order Submission Bug Fix

## Issue Summary

Order #1003 (UID: 37124642) entered production state but failed to complete the Shopify draft order, resulting in:

- ✅ Has `shopify_remote_draft_order_id`
- ❌ Missing `shopify_remote_order_id`
- ❌ Missing `shopify_remote_order_name`
- ❌ Order is in `in_production` state but Shopify draft was never completed

## Root Causes

### Bug 1: Silent Failure in OrderProductionService

**Location:** `app/services/order_production_service.rb:40-41`

The service called `complete_draft_order(draft_order_gid)` but **never checked if it succeeded**:

```ruby
# BEFORE (BUGGY)
complete_draft_order(draft_order_gid)
steps[:step3][:status] = "success"  # Always marked success!
```

This caused the service to:

1. Return `{ success: true }` even though step 3 failed
2. Trigger the controller to call `@order.submit!`
3. Transition the order to `in_production` state
4. Leave the order in an invalid state

### Bug 2: Missing Shopify Customer Validation

**Location:** `app/models/order.rb:27`

The order could be submitted even when the user had no `ShopifyCustomer` record for the order's country.

**Error that occurred:**

```
Error updating draft order customer: User gcoltart@mac.com has no Shopify customer for country NZ
```

The `DraftOrderService.update_customer` method raised an exception when it couldn't find a Shopify customer, but this wasn't validated before attempting submission.

## Fixes Implemented

### Fix 1: Check Step 3 Success

**File:** `app/services/order_production_service.rb`

```ruby
# AFTER (FIXED)
unless complete_draft_order(draft_order_gid)
  steps[:step3][:status] = "error"
  return { success: false, steps: steps, error: "Failed to complete Shopify draft order", failed_step: 3 }
end
steps[:step3][:status] = "success"
```

Now the service properly checks if the draft order completion succeeded and returns an error if it fails.

### Fix 2: Add Shopify Customer Guard

**File:** `app/models/order.rb`

Added new guard method:

```ruby
def has_shopify_customer_for_country?
  # Only required for Shopify stores
  return true unless store.platform == "shopify"

  # Country code is required
  return false unless country_code.present?

  # Check if the user has a Shopify customer for this country
  store.user.shopify_customers.exists?(country_code: country_code)
end
```

Updated the submit event to include both guards:

```ruby
event :submit do
  transitions from: :draft, to: :in_production,
              guard: [ :all_items_have_variant_mappings?, :has_shopify_customer_for_country? ]
end
```

### Fix 3: Return False Instead of Raising

**File:** `app/services/shopify/draft_order_service.rb`

Changed from raising an exception to returning false:

```ruby
# BEFORE
raise "User #{user.email} has no Shopify customer for country #{order.country_code}" unless shopify_customer

# AFTER
unless shopify_customer
  Rails.logger.error "User #{user.email} has no Shopify customer for country #{order.country_code}"
  return false
end
```

This makes the error handling consistent with the rest of the service.

## Verification

Tested the guard with the problematic order:

```
Order: #1003
Country: NZ
Store platform: shopify
User email: gcoltart@mac.com

Checking guards:
1. all_items_have_variant_mappings? => true
2. has_shopify_customer_for_country? => false

may_submit? => false  ✅ Would have prevented the issue!
```

## Impact

### Before Fix

- Orders could be submitted without required Shopify customer setup
- Step 3 failures were silently ignored
- Orders entered invalid states (in_production without Shopify order IDs)

### After Fix

- Orders cannot be submitted unless user has a Shopify customer for the country ✅
- Step 3 failures properly stop the submission process ✅
- Orders maintain data consistency ✅
- Users receive clear error messages about missing setup ✅

## Required User Action

Users must create a `ShopifyCustomer` record for each country they want to fulfill orders to. This ensures:

1. B2B company information is available
2. Draft orders can be properly completed
3. Production orders are valid in Shopify

## Date

October 29, 2025
