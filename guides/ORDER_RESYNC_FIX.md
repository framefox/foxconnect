# Order Resync Bug Fix

## Problem Description

When an order was imported before products were synced:
1. Order would be created with order items
2. Order items had `external_variant_id` but no `product_variant_id` (because products didn't exist yet)
3. After running product sync, products and variants were created
4. Running "Resync from Shopify" would NOT populate the `product_variant_id` and `variant_mapping_id` fields
5. Order items remained disconnected from products

## Root Cause

In `app/services/import_order_service.rb`:

### Issue #1: `update_order_item` method (line 505-546)
```ruby
order_item.save!

# Re-resolve variant associations in case they changed
order_item.resolve_variant_associations!

Rails.logger.info "Updated order item: #{order_item.display_name}"
```

The problem:
- `resolve_variant_associations!` sets `product_variant` and `variant_mapping` on the object
- But it doesn't save (see `order_item.rb` lines 85-86 where save is commented out)
- So the associations were set in memory but never persisted to the database

### Issue #2: `create_order_item` method (line 545-582)
```ruby
order_item.save!

Rails.logger.info "Created new order item: #{order_item.display_name}"
```

The problem:
- Relied only on the `before_validation :auto_resolve_variant_associations, on: :create` callback
- During resync, when creating new items, the callback would run
- But if products were synced after the order, the associations still wouldn't resolve properly

## Solution

### Fix #1: Save after resolving in `update_order_item`
```ruby
order_item.save!

# Re-resolve variant associations in case they changed
order_item.resolve_variant_associations!

# Save again to persist the resolved associations
order_item.save! if order_item.changed?

Rails.logger.info "Updated order item: #{order_item.display_name}"
```

### Fix #2: Explicitly resolve and save in `create_order_item`
```ruby
order_item.save!

# Explicitly resolve variant associations after save for resync scenarios
# where products might have been synced after the order was imported
order_item.resolve_variant_associations!
order_item.save! if order_item.changed?

Rails.logger.info "Created new order item: #{order_item.display_name}"
order_item
```

## Testing

For order #16317074 (or any affected order):

1. Check order items before fix:
```ruby
Order.find_by(external_id: '16317074').order_items.map { |oi| [oi.id, oi.product_variant_id, oi.variant_mapping_id] }
# Should show nil values for product_variant_id and variant_mapping_id
```

2. Run resync after fix:
- Go to the order page
- Click "Resync from Shopify"

3. Check order items after resync:
```ruby
Order.find_by(external_id: '16317074').order_items.map { |oi| [oi.id, oi.product_variant_id, oi.variant_mapping_id] }
# Should now show populated product_variant_id values
```

## Impact

This fix ensures that:
- Orders imported before products are synced can be fully populated when resynced
- Existing order items will have their product associations resolved during resync
- New order items created during resync will have their associations properly set
- Variant mappings will be automatically created when default mappings exist

## Files Changed

- `app/services/import_order_service.rb` - Added save calls after `resolve_variant_associations!`

