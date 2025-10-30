# Order Fulfillment State Enhancement

## Summary

This implementation enhances the order fulfillment system to properly transition orders to the "fulfilled" state when all fulfillable items are fulfilled, and introduces a "Partially Fulfilled" inferred state for orders in production with some fulfilled items.

## Changes Made

### 1. Order Model (`app/models/order.rb`)

#### Updated `fully_fulfilled?` Method

**Before:**
```ruby
def fully_fulfilled?
  return false if active_order_items.none?
  active_order_items.all?(&:fully_fulfilled?)
end
```

**After:**
```ruby
def fully_fulfilled?
  return false if fulfillable_items.none?
  fulfillable_items.all?(&:fully_fulfilled?)
end
```

**Rationale:** The order should only check if fulfillable items are fulfilled, not all items. Non-fulfillable items (e.g., digital products, services) should not prevent an order from being marked as fulfilled.

#### Added `display_state` Method

```ruby
def display_state
  if in_production? && partially_fulfilled?
    :partially_fulfilled
  else
    aasm_state.to_sym
  end
end
```

**Purpose:** Provides an inferred state that includes "partially_fulfilled" for orders that are in production and have some (but not all) fulfillable items fulfilled. This is a display-only state and does not affect the actual AASM state machine.

### 2. Application Helper (`app/helpers/application_helper.rb`)

#### Updated `order_state_badge` Method

**Changes:**
- Changed from checking `order.aasm_state` to `order.display_state`
- Added a new badge case for `:partially_fulfilled` state
- Badge uses amber color scheme (amber-100 background, amber-800 text)
- Uses "PackageIcon" for the partially fulfilled badge

**Badge Appearance:**
- **Draft:** Gray badge with "OrderDraftIcon"
- **In Production:** Blue badge with "PackageFulfilledIcon"
- **Partially Fulfilled:** Amber badge with "PackageIcon" ⭐ NEW
- **Fulfilled:** Green badge with "OrderFulfilledIcon"
- **Cancelled:** Red badge with "XCircleIcon"

### 3. State Transition Logic

The existing fulfillment logic in both `FulfillmentsController` and `InboundFulfillmentService` already checks if the order is fully fulfilled and triggers the state transition:

```ruby
if @order.fully_fulfilled?
  @order.fulfill! if @order.may_fulfill?
end
```

With the updated `fully_fulfilled?` method, this will now correctly transition orders to "fulfilled" when all **fulfillable items** are fulfilled, regardless of non-fulfillable items.

## State Flow

### Order States (AASM)

1. **draft** (initial state)
2. **in_production** (after submission)
3. **fulfilled** (when all fulfillable items are fulfilled)
4. **cancelled**

### Display States (Inferred)

The `display_state` method provides these states for UI display:

1. **draft** - Order is in draft
2. **in_production** - Order is in production, no items fulfilled yet
3. **partially_fulfilled** ⭐ - Order is in production, some fulfillable items fulfilled
4. **fulfilled** - All fulfillable items are fulfilled
5. **cancelled** - Order is cancelled

## Examples

### Example 1: Order with Only Fulfillable Items

**Order Items:**
- 2x Framed Print (fulfillable)
- 1x Canvas Print (fulfillable)

**Scenario:**
1. Order submitted → State: `in_production`, Display: "In Production"
2. 2x Framed Print fulfilled → State: `in_production`, Display: "Partially Fulfilled"
3. 1x Canvas Print fulfilled → State: `fulfilled`, Display: "Fulfilled"

### Example 2: Order with Mixed Items

**Order Items:**
- 2x Framed Print (fulfillable)
- 1x Digital Download (non-fulfillable)

**Scenario:**
1. Order submitted → State: `in_production`, Display: "In Production"
2. 1x Framed Print fulfilled → State: `in_production`, Display: "Partially Fulfilled"
3. 2x Framed Print fulfilled → State: `fulfilled`, Display: "Fulfilled"

Note: The digital download does not need to be fulfilled for the order to reach "fulfilled" state.

### Example 3: Order with Only Non-Fulfillable Items

**Order Items:**
- 1x Digital Download (non-fulfillable)
- 1x Service Fee (non-fulfillable)

**Scenario:**
- Order cannot be submitted for production (guard: `all_items_have_variant_mappings?` requires at least one fulfillable item)

## UI Impact

### Views Updated (Automatically via Helper)

All views that use `order_state_badge(order)` will automatically display the new "Partially Fulfilled" state:

1. **Orders Index** (`app/views/orders/index.html.erb`)
2. **Order Show** (`app/views/orders/show.html.erb`)
3. **Admin Orders Index** (`app/views/admin/orders/index.html.erb`)
4. **Admin Order Show** (`app/views/admin/orders/show.html.erb`)

### No Changes Required

The views already use the centralized `order_state_badge` helper, so no view changes were necessary.

## Testing Recommendations

### Manual Testing Scenarios

1. **Test Partial Fulfillment:**
   - Create an order with 3 fulfillable items
   - Submit for production
   - Fulfill 1 item → Verify "Partially Fulfilled" badge appears
   - Fulfill remaining items → Verify "Fulfilled" badge appears and state transitions

2. **Test Mixed Items:**
   - Create an order with 2 fulfillable and 1 non-fulfillable item
   - Submit for production
   - Fulfill all fulfillable items → Verify order transitions to "fulfilled"

3. **Test Multiple Fulfillments:**
   - Create an order with 5 items
   - Create first fulfillment with 2 items → Verify "Partially Fulfilled"
   - Create second fulfillment with 3 items → Verify "Fulfilled"

### Automated Testing (Future)

Consider adding tests for:
- `Order#fully_fulfilled?` with various item configurations
- `Order#display_state` with different fulfillment scenarios
- `Order#partially_fulfilled?` edge cases

## Database Impact

No database migrations required. This is a pure logic and display enhancement.

## Backward Compatibility

✅ **Fully backward compatible**

- Existing orders will work correctly with the new logic
- The AASM state machine is unchanged
- Only the fulfillment check logic and display state are enhanced

## Related Files

- `app/models/order.rb`
- `app/models/order_item.rb`
- `app/helpers/application_helper.rb`
- `app/controllers/fulfillments_controller.rb`
- `app/services/inbound_fulfillment_service.rb`

## Future Enhancements

1. Add filtering by "Partially Fulfilled" state in order lists
2. Add notifications when orders become partially fulfilled
3. Add analytics/reporting for fulfillment rates
4. Consider adding a "partially_fulfilled_at" timestamp field

