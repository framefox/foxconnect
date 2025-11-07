# OrderItemCard Bundle Null Reference Fixes

## Problem

After fixing the backend to copy bundle mappings, the OrderItemCard component was throwing multiple `TypeError: Cannot read properties of null (reading 'framed_preview_thumbnail')` errors.

### Root Cause

The component uses two different variables for mappings:
- `variantMapping` - For single-slot items (can be null)
- `bundleMappings` - Array for bundle items

The variable `hasVariantMapping` was defined as:
```javascript
const hasVariantMapping = variantMapping !== null || bundleMappings.length > 0;
```

This meant `hasVariantMapping` could be `true` for bundles (when `bundleMappings.length > 0`), but `variantMapping` would still be `null`. Multiple places in the code checked `hasVariantMapping` and then tried to access `variantMapping.property` directly, causing null reference errors.

## Fixes Applied

**File:** `app/javascript/components/OrderItemCard.js`

### 1. Line 105 - useEffect Hook (Image Loading)

**Before:**
```javascript
if (hasVariantMapping && variantMapping.framed_preview_thumbnail) {
```

**After:**
```javascript
if (!isBundle && variantMapping && variantMapping.framed_preview_thumbnail) {
```

Also updated dependencies array to include `isBundle`.

### 2. Line 254 - Single Mapping Preview Image

**Before:**
```javascript
hasVariantMapping && variantMapping.framed_preview_thumbnail ? (
```

**After:**
```javascript
!isBundle && variantMapping && variantMapping.framed_preview_thumbnail ? (
```

### 3. Line 313 - Add Image Button

**Before:**
```javascript
hasVariantMapping &&
  !variantMapping.framed_preview_thumbnail &&
  !readOnly ? (
```

**After:**
```javascript
!isBundle && variantMapping &&
  !variantMapping.framed_preview_thumbnail &&
  !readOnly ? (
```

### 4. Line 473 - Product Details Section

**Before:**
```javascript
hasVariantMapping ? (
```

**After:**
```javascript
!isBundle && variantMapping ? (
```

This section displays dimensions, frame description, and image filename.

### 5. Line 625 - Lightbox Component

**Before:**
```javascript
{hasVariantMapping && variantMapping.framed_preview_thumbnail && (
```

**After:**
```javascript
{!isBundle && variantMapping && variantMapping.framed_preview_thumbnail && (
```

## Pattern Applied

For all sections that display single-mapping data, changed from:
```javascript
hasVariantMapping && variantMapping.property
```

To:
```javascript
!isBundle && variantMapping && variantMapping.property
```

This ensures:
1. We only render single-mapping UI for non-bundle items
2. We check `variantMapping` is not null before accessing properties
3. Bundle items use their own dedicated UI rendering path

## Sections Already Safe

These sections already used optional chaining and were safe:
- Line 385: `variantMapping?.frame_sku_cost_dollars`
- Line 391: `variantMapping?.frame_sku_cost_dollars > 0`

## Testing

After these fixes:
1. ✅ Bundle items (2+ slots) display correctly with grid layout
2. ✅ Single-slot items display correctly with image preview
3. ✅ No null reference errors in console
4. ✅ All interactive features work (edit, delete, restore)

## Date

November 7, 2025

