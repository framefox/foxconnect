# Bundle Order Import Fix

## Problem

When orders were imported from Shopify/Squarespace, the bundle variant_mappings were **not being copied** from the ProductVariant to the OrderItem. This meant that orders with bundle products showed no bundle slots in the UI.

### Root Cause

The `OrderItem.resolve_variant_associations!` method (called during order import) only copied the old single `variant_mapping` field but never called `copy_bundle_mappings_from_variant` to copy multi-slot bundle mappings.

## Solution

### 1. Modified `OrderItem` Model

**File:** `app/models/order_item.rb`

#### Added Callback
```ruby
after_create :copy_bundle_mappings_if_needed
```

This callback runs after an OrderItem is created and automatically copies bundle mappings if the product has a multi-slot bundle.

#### Updated `resolve_variant_associations!`
- Simplified to only handle single-slot default mappings in the before_validation phase
- Multi-slot bundles are now handled by the after_create callback

#### Added Private Method `copy_bundle_mappings_if_needed`
```ruby
def copy_bundle_mappings_if_needed
  # Skip for custom items
  return if is_custom?
  
  # Only copy bundle mappings if product_variant has a multi-slot bundle
  return unless product_variant&.bundle
  return unless product_variant.bundle.slot_count > 1
  return unless product_variant.bundle.variant_mappings.any?
  
  # Copy the bundle mappings
  copy_bundle_mappings_from_variant
end
```

#### Fixed `copy_bundle_mappings_from_variant`
Added `is_default: false` to copied mappings to avoid validation errors:
```ruby
copied_mapping.is_default = false  # Order item mappings are never defaults
```

## Testing

### Verified Order #41804069

Order had 3 items:
1. **Sunset - A4 / Black** (2-slot bundle) ✅ Now shows 2 slots
2. **Sunset - A4 / White** (2-slot bundle) ✅ Now shows 2 slots  
3. **Sunset - A4 / Oak** (1-slot bundle, no template mappings) - Expected behavior

### UI Verification

The OrderItemCard component correctly displays:
- Bundle grid layout for multi-slot items
- Individual slot details
- Combined cost calculations
- Slot editing capabilities

## Migration Path

### New Orders
All new orders imported after this fix will automatically have bundle mappings copied correctly.

### Existing Orders

To fix existing orders with bundles, run this script:

```ruby
# Find orders that need fixing
orders_to_fix = Order.joins(order_items: { product_variant: :bundle })
  .where('bundles.slot_count > 1')
  .where('order_items.bundle_slot_count IS NULL OR order_items.bundle_slot_count = 0')
  .distinct

orders_to_fix.each do |order|
  puts "Fixing Order: #{order.display_name}"
  
  order.order_items.each do |item|
    next unless item.product_variant&.bundle
    next unless item.product_variant.bundle.slot_count > 1
    next unless item.product_variant.bundle.variant_mappings.any?
    
    # Set bundle_slot_count
    item.update_column(:bundle_slot_count, item.product_variant.bundle.slot_count)
    
    # Copy template mappings
    item.product_variant.bundle.variant_mappings.order(:slot_position).each do |template|
      # Skip if already exists
      next if item.variant_mappings.exists?(slot_position: template.slot_position)
      
      copied = template.dup
      copied.bundle_id = nil
      copied.order_item_id = item.id
      copied.slot_position = template.slot_position
      copied.is_default = false
      copied.save!
      
      puts "  ✓ Copied slot #{template.slot_position} for #{item.display_name}"
    end
  end
end
```

## Related Files

- `app/models/order_item.rb` - Main fix location
- `app/models/product_variant.rb` - Bundle associations
- `app/models/bundle.rb` - Bundle model
- `app/models/variant_mapping.rb` - Mapping model with slot_position
- `app/javascript/components/OrderItemCard.js` - UI component (already bundle-ready)
- `app/views/orders/show.html.erb` - Passes bundle data to UI

## Future Improvements

Consider adding:
1. A rake task to fix all existing orders
2. Data migration to backfill missing bundle_slot_count values
3. Admin UI warning when orders have misconfigured bundles

## Status

✅ **FIXED** - New orders will import correctly
⚠️ **MANUAL FIX NEEDED** - Existing orders with bundles need the migration script run

## Date

November 7, 2025

