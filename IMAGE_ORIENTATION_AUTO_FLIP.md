# Image Orientation Auto-Flip Implementation

## Overview

Implemented automatic dimension orientation adjustment when images are added or changed on existing variant mappings. The system now detects the crop orientation and automatically flips the width/height to match the cropped image's aspect ratio.

## Problem Statement

Previously, if a variant mapping existed with dimensions (e.g., 30x40cm portrait) and a user added a landscape image cropped at 40x30 ratio, the dimensions would remain at 30x40cm, which didn't match the actual crop orientation.

## Solution

Modified the `calculate_dimensions_from_frame_sku` method in the `VariantMapping` model to:

1. **Always recalculate dimensions when the image changes** - Uses `image_id_changed?` to detect when a new image is being added or replaced
2. **Preserve custom dimensions when image hasn't changed** - If dimensions are manually set and the image hasn't changed, those custom dimensions are preserved
3. **Orient dimensions based on crop ratio** - Determines orientation from crop dimensions (cw/ch) and assigns frame_sku_long/short accordingly

## Logic Flow

```ruby
# Only calculate if we have frame_sku values and crop dimensions
return unless frame_sku_long.present? && frame_sku_short.present? && cw.present? && ch.present?

# If dimensions exist AND image hasn't changed, preserve them (custom size override)
if width.present? && height.present? && unit.present? && !image_id_changed?
  return
end

# Determine orientation based on crop dimensions
if cw >= ch
  # Landscape or square - width gets the long dimension
  self.width = frame_sku_long
  self.height = frame_sku_short
else
  # Portrait - width gets the short dimension  
  self.width = frame_sku_short
  self.height = frame_sku_long
end
```

## Examples

### Example 1: Adding Image to Existing Variant Mapping

**Scenario:**
- Variant mapping exists with frame_sku_long=40cm, frame_sku_short=30cm
- Current dimensions: 30x40cm (portrait)
- User adds landscape image cropped at 40:30 ratio (cw=800, ch=600)

**Result:**
- System detects `image_id_changed? = true`
- Recalculates: cw >= ch → landscape
- New dimensions: 40x30cm (landscape) ✓

### Example 2: Adding Image to Existing Variant Mapping (Opposite)

**Scenario:**
- Variant mapping exists with frame_sku_long=40cm, frame_sku_short=30cm  
- Current dimensions: 40x30cm (landscape)
- User adds portrait image cropped at 30:40 ratio (cw=600, ch=800)

**Result:**
- System detects `image_id_changed? = true`
- Recalculates: ch > cw → portrait
- New dimensions: 30x40cm (portrait) ✓

### Example 3: Creating New Variant Mapping

**Scenario:**
- Creating new variant mapping with portrait crop (cw=600, ch=800)
- frame_sku_long=40cm, frame_sku_short=30cm

**Result:**
- No existing dimensions
- Calculates: ch > cw → portrait
- New dimensions: 30x40cm (portrait) ✓

### Example 4: Custom Size Preservation

**Scenario:**
- Variant mapping has custom dimensions: 50x70cm
- User updates other fields (e.g., frame color) but doesn't change the image

**Result:**
- `image_id_changed? = false`
- Custom dimensions preserved: 50x70cm ✓

## Model Changes

### File: `app/models/variant_mapping.rb`

- **Modified:** `calculate_dimensions_from_frame_sku` private method (lines 325-350)
- **Key Change:** Added `!image_id_changed?` check to determine when to skip recalculation

## Benefits

1. **Automatic Orientation** - No manual intervention needed when swapping landscape/portrait images
2. **Custom Size Support** - Preserves manually set dimensions when image isn't changing
3. **Consistent Behavior** - Works for both new variant mappings and updates
4. **Order Item Support** - Works correctly for both product variant mappings and order item-specific mappings

## Technical Notes

- Uses ActiveRecord's `image_id_changed?` dirty tracking method
- Runs in `before_validation` callback, ensuring dimensions are set before save
- Respects existing `frame_sku_long`/`frame_sku_short` values (doesn't modify them)
- Works with delegated crop dimensions from the associated `Image` model

## Related Files

- `app/models/variant_mapping.rb` - Core logic
- `app/models/image.rb` - Stores crop coordinates (cx, cy, cw, ch)
- `app/controllers/variant_mappings_controller.rb` - Handles image association

