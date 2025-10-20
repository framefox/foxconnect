# Variant Mapping Dimensions Implementation

## Overview

Added automatic calculation and storage of product dimensions (`width`, `height`, `unit`) to the `variant_mappings` table based on frame SKU dimensions and artwork orientation.

## Database Changes

### Migration: `AddWidthHeightUnitToVariantMappings`

Added three new columns to `variant_mappings`:

- `width` - `decimal(6,2)` - Final product width
- `height` - `decimal(6,2)` - Final product height
- `unit` - `string` - Measurement unit (e.g., "mm", "cm", "inches")

## Implementation Details

### Automatic Dimension Calculation

The `VariantMapping` model now includes a `before_validation` callback that automatically calculates the final product dimensions based on:

1. **Frame SKU Dimensions**: `frame_sku_long`, `frame_sku_short`, `frame_sku_unit`
2. **Crop Orientation**: `cw` (crop width), `ch` (crop height)

### Logic

The callback determines the final product orientation by comparing crop dimensions:

- **Landscape/Square** (cw >= ch):
  - `width = frame_sku_long`
  - `height = frame_sku_short`
- **Portrait** (ch > cw):

  - `width = frame_sku_short`
  - `height = frame_sku_long`

- **Unit**: Direct copy from `frame_sku_unit`

### Example

If a frame SKU has:

- `frame_sku_long = 600`
- `frame_sku_short = 400`
- `frame_sku_unit = "mm"`

And the artwork is cropped to:

- **Landscape** (cw: 800, ch: 600) → `width: 600, height: 400, unit: "mm"`
- **Portrait** (cw: 600, ch: 800) → `width: 400, height: 600, unit: "mm"`

## Code Changes

### Model: `app/models/variant_mapping.rb`

- Added `before_validation :calculate_dimensions_from_frame_sku` callback
- Implemented `calculate_dimensions_from_frame_sku` private method

### Controller: `app/controllers/variant_mappings_controller.rb`

- Added `:width`, `:height`, `:unit` to permitted parameters
- Added these fields to JSON responses in `create` and `update` actions

### No Frontend Changes Required

The JavaScript components already send `frame_sku_long`, `frame_sku_short`, and `frame_sku_unit` in the request payload. The automatic calculation happens server-side, so no frontend changes were needed.

## API Response

Variant mapping JSON responses now include:

```json
{
  "width": 600.0,
  "height": 400.0,
  "unit": "mm",
  "frame_sku_long": 600,
  "frame_sku_short": 400,
  "frame_sku_unit": "mm",
  ...
}
```

## Benefits

1. **Automatic**: Dimensions are calculated automatically on save
2. **Orientation-aware**: Correctly flips dimensions based on artwork orientation
3. **Consistent**: Same logic applies to all variant mappings (default and order-specific)
4. **API-ready**: Dimensions are included in all JSON responses for easy frontend consumption

