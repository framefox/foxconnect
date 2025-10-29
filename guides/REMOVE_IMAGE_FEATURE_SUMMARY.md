# Remove Image Feature - Implementation Summary

## Overview

Added the ability to remove only the image from a variant mapping while keeping the product/frame SKU details intact. This allows users to have variant mappings with product information but no image, which can be added later.

## Changes Made

### 1. Backend - Controller & Routes

**File**: `app/controllers/variant_mappings_controller.rb`

Added new `remove_image` action that:

- Sets the `image` association to `nil` on the variant mapping
- Keeps all frame SKU details intact
- Returns success/error JSON response

**File**: `config/routes.rb`

Added new route:

```ruby
delete :remove_image
```

Path: `DELETE /variant_mappings/:id/remove_image`

### 2. Frontend - VariantCard Component

**File**: `app/javascript/components/VariantCard.js`

#### New Functionality:

1. **`handleRemoveImage()` function**

   - Calls the new endpoint to remove the image
   - Updates local state to clear all image-related fields
   - Keeps the variant mapping with product details

2. **Updated UI when no image present:**

   - Shows amber-bordered placeholder with "No image" text and icon
   - Displays an "Add image" button for easy access to add artwork
   - Hides image-specific options in dropdown menu

3. **Updated Dropdown Menu:**
   - **"Sync image to Shopify"** - Only shows when image exists
   - **"Remove image only"** - Only shows when image exists, removes just the image
   - **Separator**
   - **"Remove product & image"** - Always shows, removes entire mapping (now in red for clarity)

## User Experience

### With Image:

- Shows framed preview thumbnail
- Shows image filename
- Dropdown shows: "Sync image to Shopify" | "Remove image only" | [separator] | "Remove product & image"

### Without Image:

- Shows amber placeholder box with "No image" text
- Shows "Add image" button
- Dropdown shows only: "Remove product & image"

## Visual States

1. **Complete Mapping (Product + Image)**

   - ✅ Preview image displayed
   - ✅ Image filename shown
   - ✅ All dropdown options available

2. **Product Only (No Image)**

   - ⚠️ Amber placeholder displayed
   - ⚠️ "Add image" button prominent
   - ⚠️ No image filename shown
   - ⚠️ Image-specific options hidden
   - ⚠️ Cannot be submitted to production (validation blocks it)

3. **No Mapping**
   - ℹ️ "Choose product & image" button shown

## Integration with Existing Features

- **Production submission validation** still enforces that all variant mappings must have images before submitting
- **Product select modal** can be reopened to add an image to a product-only mapping
- **Image association** is properly managed through the existing Image model
- **JSON serialization** correctly returns `null` for image fields when no image present

## Benefits

1. **Flexibility**: Users can set up product details first, add images later
2. **Workflow Support**: Allows partial setup of variant mappings
3. **Clear Visual Feedback**: Users immediately see which mappings need images
4. **Easy Recovery**: Simple "Add image" button to complete the mapping
5. **Safety**: Production validation prevents submitting incomplete mappings

## Testing Recommendations

1. Create a variant mapping with product and image
2. Use "Remove image only" to remove just the image
3. Verify the amber placeholder and "Add image" button appear
4. Click "Add image" and add a new artwork
5. Verify the image is successfully added to the existing mapping
6. Verify dropdown menu shows/hides appropriate options based on image presence
7. Verify order cannot be submitted when variant mappings lack images
