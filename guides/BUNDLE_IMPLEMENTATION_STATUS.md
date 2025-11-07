# Bundle Implementation Status

## Completed (Backend Infrastructure)

### Database Schema ✅
- Created `bundles` table with `product_variant_id` and `slot_count`
- Added `bundle_id`, `order_item_id`, and `slot_position` to `variant_mappings`
- Added `bundle_slot_count` to `order_items` (snapshots slot count at order creation)
- Added composite unique indexes for bundle/order_item + slot_position combinations
- Migrated existing data: created bundles for all ProductVariants, migrated default mappings

### Models ✅
- **Bundle model**: Created with associations and validations
- **ProductVariant**: Added `has_one :bundle`, callback to create default bundle, helper methods (`slot_count`, `is_bundle?`, `template_variant_mappings`)
- **VariantMapping**: Added `belongs_to :bundle` and `belongs_to :order_item`, bundle-related scopes and validations
- **OrderItem**: Added `has_many :variant_mappings`, `bundle_slot_count`, bundle-aware methods (`is_bundle?`, `slot_count`, `all_slots_filled?`, `total_frame_cost`, `copy_bundle_mappings_from_variant`)
- **Order**: Updated validation methods to check all bundle slots are filled

### Services ✅
- **Production::ApiClient**: Updated `build_payload` to iterate through variant_mappings and split bundles into separate line items for production

### Controllers ✅
- **ProductVariantsController**: Added `update_bundle` endpoint
- Route: `PATCH /connections/stores/:store_uid/product_variants/:id/update_bundle`

### Views ✅
- **products/show.html.erb**: Updated to pass bundle data with variant_mappings array to React component

## Remaining Work

### Controllers ✅ (Complete for MVP)

**Connections::Stores::ProductVariantsController** ✅
- Added `update_bundle` action to change slot_count
- Validates slot_count (1-10)
- Checks if slots can be safely removed
- Returns bundle data with variant_mappings in JSON
- Route added: `PATCH /connections/stores/:store_uid/product_variants/:id/update_bundle`

**VariantMappingsController** (Future Enhancement)
- Could add specific endpoints for bundle slot management
- Current create/update endpoints will work with bundle_id and slot_position params
- Validations are in the model layer

**OrderItemsController** (Future Enhancement)
- Could add endpoints to return variant_mappings array
- Current functionality should work with the has_many association

### UI Components (In Progress)

**VariantCard.js** 🚧
- State management added for bundle support
- Implementation guide created: `VARIANT_CARD_BUNDLE_IMPLEMENTATION.md`
- Needs: Render logic updates for slot grid, combined cost display
- Status: 20% complete (state added, rendering needed)

**OrderItemCard.js** ⏳
- Similar updates needed as VariantCard
- Must handle `item.variant_mappings` array and `item.bundle_slot_count`
- Status: Not started

**ProductSelectModal** ⏳
- Needs to accept `slotPosition` and `bundleId` props
- Pass these to backend when creating/updating variant_mappings
- Status: Not started

**BundleConfigPanel.js** ⏳ (New Component - Optional)
- Admin UI to change bundle slot_count
- Can use API endpoint already created
- Status: Not started (can be done via console for now)

## Testing (Not Started)
- Test single-slot bundles work as before
- Test multi-slot bundle configuration
- Test order creation with bundles
- Test production submission splits bundles correctly

## Key Design Decisions Made

1. **Single Code Path**: All variant mappings go through Bundles, even single mappings (slot_count: 1)
2. **No Bundle Copying**: When orders are created, only VariantMappings are copied, not Bundle records
3. **Slot Position**: Maintained through `slot_position` field on VariantMapping
4. **Backward Compatible**: Old single `variant_mapping_id` field on OrderItem still supported
5. **Data Migration**: Only migrated one default mapping per variant to avoid conflicts

## Migration Notes

The data migration currently:
- Creates a Bundle (slot_count: 1) for every ProductVariant
- Migrates only ONE default VariantMapping per variant to bundle_id/slot_position: 1
- Other variant mappings (non-default or additional country mappings) remain with `product_variant_id` for now

This conservative approach ensures backward compatibility. Multi-slot bundles will be created when users explicitly configure them.

## Next Steps

1. Add controller actions for bundle management
2. Implement UI components for slot display and editing
3. Add bundle configuration UI
4. Test end-to-end flow
5. Document usage for end users

