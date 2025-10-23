# Order UID Migration

## Overview
Migrated the Order model from using database IDs in URLs to using unique identifiers (UIDs) for improved security and consistency with the Store model pattern.

## Implementation Date
October 23, 2025

## Changes Made

### 1. Database Migration
**File**: `db/migrate/20251023014854_add_uid_to_orders.rb`
- Added `uid` column to orders table (string, non-null, unique)
- Generated 10-character alphanumeric UIDs for all existing orders
- Added unique index on `uid` column

### 2. Order Model Updates
**File**: `app/models/order.rb`
- Added validation: `validates :uid, presence: true, uniqueness: true`
- Added callback: `before_validation :generate_uid, on: :create`
- Added `to_param` method to use UID in URLs instead of database ID
- Added private `generate_uid` method that generates 10-character lowercase alphanumeric UIDs

### 3. Controller Updates
**Files**: 
- `app/controllers/orders_controller.rb`
- `app/controllers/admin/orders_controller.rb`

Changed finder methods from:
```ruby
.find(params[:id])
```

To:
```ruby
.find_by!(uid: params[:id])
```

### 4. View Updates
**File**: `app/views/orders/show.html.erb`
- Updated `SubmitProductionButton` React component to receive UID instead of database ID
  - Changed `orderId: @order.id` to `orderId: @order.uid`
- Updated all `OrderItemCard` React components (4 occurrences) to receive UID instead of database ID
  - Changed `order_id: item.order_id` to `order_id: @order.uid`
  - Affects: unfulfilled items, fulfilled items, fulfillable items, and removed items sections

## Key Differences from Store UIDs
- **Length**: Orders use 10 characters (vs 8 for stores)
- **Pattern**: Both use lowercase alphanumeric characters
- **Implementation**: Identical pattern to stores with `to_param` override

## Benefits
1. **Security**: Database IDs are no longer exposed in URLs
2. **Consistency**: Orders now follow the same UID pattern as stores
3. **URL Stability**: UIDs provide stable, non-sequential identifiers
4. **Professional URLs**: Clean, random identifiers instead of sequential numbers

## Verification
- ✅ All 57 existing orders migrated successfully with 10-character UIDs
- ✅ URL generation works correctly (`/orders/{uid}`)
- ✅ Controllers can find orders by UID
- ✅ `to_param` method returns UID for path helpers
- ✅ No linter errors
- ✅ React components updated to use UIDs

## Example
```ruby
order = Order.first
order.id         # => 3 (database ID, internal use only)
order.uid        # => "717we1jsyf" (10 characters)
order.to_param   # => "717we1jsyf" (used in URLs)

# URL generation
order_path(order) # => "/orders/717we1jsyf"
```

## Routes Affected
All order routes now use UIDs:
- `/orders/:id` → `/orders/:uid`
- `/orders/:id/submit`
- `/orders/:id/submit_production`
- `/orders/:id/cancel_order`
- `/orders/:id/reopen`
- `/orders/:id/resync`
- `/orders/:id/resend_email`
- `/admin/orders/:id` → `/admin/orders/:uid`
- And all nested routes (order_items, fulfillments)

## Backward Compatibility
⚠️ **Breaking Change**: Old URLs using database IDs will no longer work after this migration. This is expected and desired for security.

## No Changes Required
The following continue to work without modification:
- `order_path(@order)` - Uses `to_param` automatically
- `order_url(@order)` - Uses `to_param` automatically
- All mailers - Use internal database IDs for lookups (unchanged)
- All associations - Use internal database IDs (unchanged)
- Webhooks - Use external_id for platform integration (unchanged)

