# Submit for Production Button - Fix for Orders with No Fulfillable Items

## Problem Description

Order #16317074 (and similar orders) had:
- Order items present ✅
- Products synced ✅
- But ALL items had `fulfilment_active: false` ❌
- "Submit for Production" button was **enabled** (WRONG!)

The button should have been **disabled** because there are no items to fulfill.

## Root Cause

In `app/models/order.rb`, the `all_items_have_variant_mappings?` guard method:

```ruby
def all_items_have_variant_mappings?
  return false if active_order_items.empty?
  fulfillable_items.where(variant_mapping_id: nil).none?
end
```

**The Bug:**

For orders with NO fulfillable items (all items have `fulfilment_active: false`):

1. `active_order_items.empty?` returns `false` ✅ (items exist)
2. `fulfillable_items` returns an **empty collection** (no items with `fulfilment_active: true`)
3. `fulfillable_items.where(variant_mapping_id: nil).none?` returns `true` ✅ (because the collection is empty!)
4. Guard passes, button enabled ❌ **BUG!**

The logic flaw: An empty set of fulfillable items technically has "none without mappings", so the guard passes!

## Solution

Added a check to ensure at least one fulfillable item exists:

```ruby
def all_items_have_variant_mappings?
  return false if active_order_items.empty?
  return false if fulfillable_items.none? # Must have at least one fulfillable item
  fulfillable_items.where(variant_mapping_id: nil).none?
end
```

## Requirements for "Submit for Production" Button to be Enabled

Now the button will only be enabled if ALL of these conditions are met:

1. ✅ Order is in `draft` state
2. ✅ Order has at least one active order item
3. ✅ Order has at least one **fulfillable** item (`fulfilment_active: true`)
4. ✅ All fulfillable items have variant mappings

## Testing

### Test Case 1: Order with No Fulfillable Items
```ruby
order = Order.find_by(external_id: '16317074')
order.fulfillable_items.count # => 0 (all items have fulfilment_active: false)
order.may_submit? # => false ✅ (Button disabled)
```

### Test Case 2: Order with Fulfillable Items but No Mappings
```ruby
order = Order.find(...)
order.fulfillable_items.count # => 3
order.fulfillable_items.where(variant_mapping_id: nil).count # => 3
order.may_submit? # => false ✅ (Button disabled)
```

### Test Case 3: Order with Fulfillable Items and Mappings
```ruby
order = Order.find(...)
order.fulfillable_items.count # => 3
order.fulfillable_items.where(variant_mapping_id: nil).count # => 0
order.may_submit? # => true ✅ (Button enabled)
```

### Test Case 4: Order with Mixed Items (Some Fulfillable, Some Not)
```ruby
order = Order.find(...)
order.active_order_items.count # => 5
order.fulfillable_items.count # => 2 (only 2 have fulfilment_active: true)
order.fulfillable_items.where(variant_mapping_id: nil).count # => 0
order.may_submit? # => true ✅ (Button enabled - can submit the 2 fulfillable items)
```

## Impact

- Orders with no fulfillable items will now correctly show a disabled button
- Prevents attempting to submit orders that cannot be fulfilled
- Better user experience with clear feedback about why orders can't be submitted

## Files Changed

- `app/models/order.rb` - Updated `all_items_have_variant_mappings?` guard method

