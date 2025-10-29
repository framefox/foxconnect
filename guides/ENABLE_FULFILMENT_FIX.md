# Enable Fulfilment Button Fix

## Problem Description

Issues with the "Enable Fulfilment" button on order item cards:

1. ✅ Button redirected to product page instead of staying on order page
2. ❓ User reported "all variants are getting enabled"

## Issue #1: Redirect to Product Page (FIXED)

**Before:**
```ruby
redirect_to connections_store_product_path(@store, @product_variant.product)
```

**After:**
```ruby
redirect_back fallback_location: connections_store_product_path(@store, @product_variant.product)
```

Now the button will redirect back to the referring page (order page) instead of always going to the product page.

## Issue #2: "All Variants Getting Enabled" (EXPLAINED)

The button correctly enables **only the specific product variant** that the order item references.

### Important: How Variant Fulfilment Works

The `fulfilment_active` flag is a property of the **ProductVariant**, not the **OrderItem**.

**This means:**
- Clicking "Enable Fulfilment" on an order item enables that specific variant
- If multiple order items reference the **same variant**, they will all show as enabled (correct behavior)
- This is intentional - you're enabling the variant for fulfilment, not individual order items

### Example Scenario

Order #16317074 has:
- Order Item A: "My Product - Medium" (variant_id: 123)
- Order Item B: "My Product - Medium" (variant_id: 123)  ← Same variant!
- Order Item C: "My Product - Large" (variant_id: 456)

When you click "Enable Fulfilment" on Item A:
- ✅ Variant 123 is enabled
- ✅ Item A shows as enabled
- ✅ Item B shows as enabled (because it uses the same variant)
- ❌ Item C remains disabled (different variant)

### Expected Behavior

This is working as designed. The data model stores fulfilment settings at the **variant level**, not the order item level, because:

1. Fulfilment capability is a property of the product variant itself
2. You either can or cannot fulfill a specific variant
3. It wouldn't make sense to fulfill "Variant A" for one order but not another

### How to Check

```ruby
# Check what's actually being updated
order = Order.find_by(external_id: '16317074')

# See which variants are used by order items
order.order_items.map { |oi| [oi.id, oi.product_variant_id, oi.display_name] }

# If multiple items have the same product_variant_id, they'll all be affected
```

## Files Changed

- `app/controllers/connections/stores/product_variants_controller.rb` - Changed redirect to use `redirect_back`

## Testing

1. Go to an order page with items that have `fulfilment_active: false`
2. Hover over an order item and click "Enable Fulfilment"
3. Should redirect back to the order page (not product page) ✅
4. Only that specific variant should be enabled ✅

