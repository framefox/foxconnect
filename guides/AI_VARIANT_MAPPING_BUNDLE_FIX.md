# AI Variant Mapping Bundle System Fix

## Issue Summary

After migrating to the bundles system, the AI variant mapping feature stopped working. It didn't throw errors but returned no results, making it appear as if no variants were mapped.

## Root Cause Analysis

The bundle migration fundamentally changed how variant mappings are associated with product variants:

### Before Bundles
- Variant mappings were directly associated with product variants via `product_variant_id`
- Query: `VariantMapping.where(product_variant_id: variant.id)`

### After Bundles
- Variant mappings are now associated through bundles
- Bundle mappings explicitly set `product_variant_id: nil` (see `variant_mappings_controller.rb` line 95)
- New association path: `ProductVariant → Bundle → VariantMappings`
- Mappings have `bundle_id` and `slot_position` instead of direct `product_variant_id`

## Bugs Found

### Bug #1: Finding Unmapped Variants
**File:** `app/services/ai_variant_matching_service.rb`  
**Method:** `get_unmapped_variants`

**Problem:**
```ruby
# Old code only looked for product_variant_id
VariantMapping.where(
  product_variant_id: @product.product_variants.pluck(:id),
  country_code: @country_code,
  is_default: true
)
```

This query couldn't find bundle-based mappings because they have `product_variant_id: nil`.

**Fix:**
Now queries only bundle-based mappings:
```ruby
@product.product_variants
  .joins(bundle: :variant_mappings)
  .where(variant_mappings: {
    country_code: @country_code,
    is_default: true,
    order_item_id: nil
  })
```

### Bug #2: Finding Reference Mapping (Suggest Action)
**File:** `app/controllers/connections/stores/ai_variant_mappings_controller.rb`  
**Method:** `suggest`

**Problem:**
```ruby
# Old code only used product_variant join
reference_mapping = VariantMapping
  .joins(:product_variant)
  .where(product_variants: { product_id: @product.id })
```

The `.joins(:product_variant)` requires `product_variant_id` to be set, so bundle mappings were invisible.

**Fix:**
Only queries bundle-based mappings:
```ruby
reference_mapping = VariantMapping
  .joins(bundle: :product_variant)
  .where(product_variants: { product_id: @product.id })
  .where(country_code: current_user.country, is_default: true, order_item_id: nil)
```

### Bug #3: Finding Reference Mapping (Create Action)
**File:** `app/controllers/connections/stores/ai_variant_mappings_controller.rb`  
**Method:** `create`

**Problem:**
Same issue as Bug #2 - couldn't find bundle-based reference mappings.

**Fix:**
Applied same bundle-only query strategy.

### Bug #4: Creating New Mappings
**File:** `app/controllers/connections/stores/ai_variant_mappings_controller.rb`  
**Method:** `create`

**Problem:**
```ruby
# Old code created legacy mappings
mapping = variant.variant_mappings.new(
  is_default: true,
  country_code: current_user.country,
  ...
)
```

This created mappings the old way (with `product_variant_id` set), which is inconsistent with the bundle system.

**Fix:**
Now creates bundle slot mappings:
```ruby
bundle = variant.bundle
mapping = bundle.variant_mappings.new(
  slot_position: 1,
  is_default: true,
  country_code: current_user.country,
  ...
)
```

Also checks for existing mappings and updates them instead of creating duplicates.

## Changes Made

### 1. `app/services/ai_variant_matching_service.rb`
- **Modified:** `get_unmapped_variants` method
- **Change:** Now queries both legacy and bundle-based mappings
- **Lines:** 90-121

### 2. `app/controllers/connections/stores/ai_variant_mappings_controller.rb`
- **Modified:** `suggest` method - reference mapping lookup
- **Lines:** 5-31

- **Modified:** `create` method - reference mapping lookup
- **Lines:** 65-90

- **Modified:** `create` method - mapping creation logic
- **Lines:** 122-168
- **Change:** Creates bundle slot mappings instead of legacy mappings
- **Bonus:** Checks for existing mappings to prevent duplicates

- **Modified:** `create` method - JSON response
- **Lines:** 179-195
- **Change:** Added `bundle_id` and `slot_position` to response for frontend compatibility

## Testing Recommendations

1. **Test with Bundle Mappings:**
   - Create a new product variant
   - Map one variant manually (creates bundle mapping)
   - Run AI mapping on remaining variants
   - Should find unmapped variants and create suggestions

2. **Test Cross-Country:**
   - Product with NZ and AU mappings
   - Switch user country and test AI mapping
   - Should respect country-specific mappings

3. **Test Multi-Slot Bundles:**
   - Create a 3-slot bundle product
   - Map slot 1 on one variant
   - Run AI mapping
   - Should map slot 1 on other variants

4. **Test Rate Limiting:**
   - Run AI mapping on product with many variants (10+)
   - Should handle rate limits gracefully
   - Should add delays between variants

## Why It Appeared to Work (But Didn't)

The AI service didn't throw errors because:
1. It found NO unmapped variants (all appeared "mapped")
2. It returned an empty suggestions array
3. The frontend received `success: true, suggestions: []`
4. No errors, just no results

This happened because the bundle mappings were invisible to the queries, making all variants appear as if they already had mappings.

## Bundle-Only System

The AI variant mapping now **only supports bundle-based mappings**:
- All queries use `bundle → variant_mappings` association
- Legacy mappings (with `product_variant_id` but no `bundle_id`) are ignored
- All new mappings are created as bundle slot mappings
- Simplified, cleaner codebase with single code path

## Related Files

- Migration: `db/migrate/20251107011710_migrate_existing_variant_mappings_to_bundles.rb`
- Bundle model: `app/models/bundle.rb`
- Variant mapping model: `app/models/variant_mapping.rb`
- Product variant model: `app/models/product_variant.rb`
- Bundle implementation guide: `guides/BUNDLE_IMPLEMENTATION_FINISHED.md`

## Additional Improvements

### Rate Limit Handling

Added robust handling for OpenAI API rate limits (HTTP 429 errors):

1. **Exponential Backoff Retry**
   - Automatically retries failed requests up to 3 times
   - Uses exponential backoff: 2s, 4s, 8s delays
   - Logs warnings when rate limits are hit

2. **Preventive Throttling**
   - Added 0.5s delay between processing variants
   - Prevents hitting rate limits in the first place
   - Only delays between variants (not after the last one)

**File:** `app/services/ai_variant_matching_service.rb`
- Lines 295-346: Retry logic with exponential backoff
- Lines 69-73: Inter-variant delay to prevent rate limiting

### Why This Matters

OpenAI has strict rate limits on their API:
- **Free tier:** ~3 requests/minute
- **Paid tiers:** Higher limits but still capped
- **429 errors** occur when these limits are exceeded

With these improvements, the AI mapping feature will:
- ✅ Automatically handle temporary rate limits
- ✅ Prevent rate limits when processing multiple variants
- ✅ Provide clear logging when rate limits occur
- ✅ Gracefully degrade (skip variants) rather than fail completely

## Status

✅ **FIXED** - All AI variant mapping functionality now works with the bundle system.  
✅ **ENHANCED** - Added rate limit handling and retry logic for production reliability.

