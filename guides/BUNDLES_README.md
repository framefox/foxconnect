# Bundles System - Quick Reference

## 🎯 What It Does

Allows ProductVariants to be configured as bundles/sets with multiple variant_mapping slots (1-10 items). When orders are submitted to production, bundles automatically split into separate line items.

---

## 🚀 Quick Start

### Create Your First Bundle

**Option 1: Via UI (Easiest)**
1. Navigate to your product page
2. Find the variant you want to bundle
3. Under variant title, click "Bundle size" dropdown
4. Select "3 items" from the dropdown
5. Page reloads showing 3 empty slots
6. Click each slot to configure product + image
7. Done! Orders will copy all 3 slots

**Option 2: Via Console**
```ruby
# 1. Find a product variant
variant = ProductVariant.find_by(title: "Gallery Wall - 3 Pack")

# 2. Configure as 3-slot bundle
variant.bundle.update!(slot_count: 3)

# 3. Visit product page in browser
# You'll see 3 slots in a grid layout

# 4. Click each slot to configure product + image

# 5. Done! Orders will now copy all 3 slots
```

### Via API

```bash
curl -X PATCH \
  "http://localhost:3000/connections/stores/{store_uid}/product_variants/{id}/update_bundle" \
  -H "Content-Type: application/json" \
  -H "X-CSRF-Token: {token}" \
  -d '{"slot_count": 3}'
```

---

## 💡 How It Works

### Product Level (Templates)
```
ProductVariant "Gallery Wall - 3 Pack"
  └─ Bundle (slot_count: 3)
      ├─ VariantMapping (slot_position: 1) - A4 Black Frame
      ├─ VariantMapping (slot_position: 2) - A3 White Frame
      └─ VariantMapping (slot_position: 3) - A4 Oak Frame
```

### Order Level (Copies)
```
Order #1234
  └─ OrderItem (bundle_slot_count: 3, quantity: 2)
      ├─ VariantMapping (slot_position: 1)
      ├─ VariantMapping (slot_position: 2)
      └─ VariantMapping (slot_position: 3)
```

### Production (Automatic Split)
```
Production System receives 6 line items:
  - A4 Black Frame (qty: 2)
  - A3 White Frame (qty: 2)
  - A4 Oak Frame (qty: 2)
```

---

## 🎨 UI Experience

### VariantCard (Product Page)

**Single-Slot Bundle (default):**
- Looks exactly as before
- One product + image selector

**Multi-Slot Bundle:**
- Grid layout with labeled slots
- "Slot 1", "Slot 2", "Slot 3"
- Click each to add product + image
- Combined cost shown at bottom

### OrderItemCard (Order Page)

**Single-Slot:**
- Large preview image as before

**Multi-Slot Bundle:**
- Compact 2×2 grid showing all slots
- List view below with slot details
- Edit button per slot
- Combined cost × quantity

---

## 🔧 Technical Details

### Key Models

**Bundle**
- `belongs_to :product_variant`
- `has_many :variant_mappings`
- Validates `slot_count` between 1-10

**VariantMapping**
- `belongs_to :bundle` (for templates)
- `belongs_to :order_item` (for order copies)
- `slot_position` maintains order

**OrderItem**
- `has_many :variant_mappings`
- `bundle_slot_count` snapshots bundle size
- Helper methods: `is_bundle?`, `slot_count`, `all_slots_filled?`

### Key Methods

```ruby
# ProductVariant
variant.slot_count            # => 3
variant.is_bundle?            # => true
variant.template_variant_mappings  # => Array

# OrderItem
item.is_bundle?               # => true
item.slot_count               # => 3
item.all_slots_filled?        # => true/false
item.total_frame_cost         # => Money (sum of all slots)

# Order
order.all_items_have_variant_mappings?  # Validates all slots filled
```

---

## 📊 Examples

### Example 1: "Gallery Wall - 3 Pack"
```ruby
variant = ProductVariant.find(...)
variant.bundle.update!(slot_count: 3)

# Admin configures:
# Slot 1: A4 Black Frame + Landscape Image
# Slot 2: A3 White Frame + Portrait Image
# Slot 3: A4 Oak Frame + Square Image

# Customer orders qty: 2
# Production receives: 6 line items (3 frames × 2 qty each)
```

### Example 2: "Couple's Frame Set - 2 Pack"
```ruby
variant.bundle.update!(slot_count: 2)

# Slot 1: Two 8x10" frames
# Slot 2: Two 5x7" frames

# Order qty: 1
# Production receives: 2 line items
```

---

## ⚠️ Important Notes

### Validations
- Cannot submit order if any bundle slot is empty
- All slots must have images
- slot_count must be 1-10
- Cannot reduce slots if orders exist using those slots

### Backward Compatibility
- All existing products auto-converted to 1-slot bundles
- No code changes needed for existing functionality
- Old `variant_mapping_id` field still works

### Data Integrity
- Unique constraints on slot_position per bundle/order_item
- Foreign key constraints ensure data consistency
- Soft delete support maintained

---

## 🐛 Troubleshooting

### "No slots showing in UI"
- Check variant has bundle: `variant.bundle.present?`
- Check slot_count: `variant.bundle.slot_count`
- Refresh browser page

### "Can't configure slot"
- Check fulfillment enabled: `variant.fulfilment_active`
- Verify modal opens without errors (check console)

### "Order won't submit"
- Verify all slots filled: `order.all_items_have_variant_mappings?`
- Check each item: `item.all_slots_filled?`
- Ensure all mappings have images

### "Production split not working"
- Check `item.variant_mappings.any?`
- Verify `Production::ApiClient` building payload correctly
- Check production API logs

---

## 📚 Documentation

Detailed guides in `/guides/`:
- `BUNDLE_IMPLEMENTATION_FINISHED.md` - Complete overview
- `VARIANT_CARD_BUNDLE_IMPLEMENTATION.md` - UI implementation details
- `BUNDLE_IMPLEMENTATION_STATUS.md` - Development tracking
- `BUNDLES_README.md` - This file (quick reference)

---

## ✅ Checklist for First Bundle

- [ ] Identify product suitable for bundling
- [ ] Update bundle slot_count via console
- [ ] Refresh product page to see slots
- [ ] Configure each slot (product + image)
- [ ] Verify combined cost displayed
- [ ] Test order creation (manually or via webhook)
- [ ] Verify order item has all slots
- [ ] Submit order to production
- [ ] Confirm separate line items created

---

**Congratulations! Your bundle system is ready to use.** 🎉

