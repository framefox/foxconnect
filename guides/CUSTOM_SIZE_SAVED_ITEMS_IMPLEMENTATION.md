# Custom Size Support in Saved Items - Implementation Guide

## Overview
This guide documents the implementation of custom print size support in the Saved Items feature. Previously, when users saved an item with a custom size selected, only the nearest standard SKU size was stored. Now, custom size information is preserved and properly displayed when saved items are loaded.

## Implementation Summary

### 1. Database Changes

**Migration: `AddCustomPrintSizeToSavedItems`**
- Added optional `custom_print_size_id` reference to `saved_items` table
- Nullable foreign key allows saved items to exist with or without custom sizes
- File: `db/migrate/20251107004042_add_custom_print_size_to_saved_items.rb`

```ruby
add_reference :saved_items, :custom_print_size, null: true, foreign_key: true
```

### 2. Model Updates

**SavedItem Model**
- Added `belongs_to :custom_print_size, optional: true` association
- Maintains existing validations while supporting optional custom size reference

**User Model**
- Already had associations for both `saved_items` and `custom_print_sizes`
- No changes required

### 3. Controller Updates

**SavedItemsController**
- Updated `index` action to include custom print size data in response
- Now returns both `saved_frame_sku_ids` (for backward compatibility) and `saved_items` array with full custom size details
- Updated `saved_item_params` to permit `custom_print_size_id`

**Response Structure:**
```json
{
  "saved_frame_sku_ids": [123, 456],
  "saved_items": [
    {
      "frame_sku_id": 123,
      "custom_print_size_id": 5,
      "custom_print_size": {
        "id": 5,
        "long": 42.0,
        "short": 29.7,
        "unit": "cm",
        "frame_sku_size_id": 45,
        "frame_sku_size_description": "A3",
        "dimensions_display": "42×29.7cm",
        "full_description": "42×29.7cm (Priced as A3)"
      }
    }
  ]
}
```

### 4. JavaScript Updates

Both `ProductSelectionStep.js` and `ProductBrowser.js` were updated with the following changes:

#### Updated Functions

**fetchSavedItems()**
- Now fetches and merges custom size data from backend with frame SKU data from external API
- Merges `custom_print_size` information into each saved item for display

**toggleSavedItem(frameSkuId, customPrintSizeId = null)**
- Added optional `customPrintSizeId` parameter
- When saving an item with a custom size selected, passes the custom size ID to the backend
- Extracts custom size ID from selected options if a custom size is active

#### Display Updates

**Product Selection Table**
- Updated star button click handler to extract and pass custom size ID when saving
- Display logic already handled custom sizes in the "Print Size" column

**Saved Items List**
- Updated "Print Size" cell to display custom size information when present
- Shows format: `42×29.7cm Priced as A3` for custom sizes
- Falls back to standard size display when no custom size exists

**Selection Handler**
- When selecting a saved item with a custom size, properly passes custom size data to parent component
- Custom size data includes: `user_width`, `user_height`, and `user_unit`

### 5. User Flow

#### Saving an Item with Custom Size
1. User selects a product type
2. User defines or selects a custom print size
3. Frame SKU results are filtered to match the nearest standard size
4. User clicks the star icon to save the item
5. System saves both the `frame_sku_id` and `custom_print_size_id`

#### Loading Saved Items
1. User navigates to "Saved Products"
2. Backend returns saved items with custom size associations
3. External API provides frame SKU details
4. Frontend merges custom size info with frame SKU data
5. Custom sizes display in format: "42×29.7cm Priced as A3"

#### Selecting a Saved Item
1. User clicks "Select" on a saved item
2. If custom size exists, it's passed to parent component
3. Product configuration loads with custom dimensions
4. User can proceed with order using the saved custom size

## Technical Details

### Custom Size ID Format
- Standard sizes: Integer IDs (e.g., `123`)
- Custom sizes: Prefixed string format (e.g., `"custom-5"`) in dropdown selection
- Database storage: Integer `custom_print_size_id` in saved_items table

### Backward Compatibility
- Existing saved items without custom sizes continue to work normally
- API response includes both old format (`saved_frame_sku_ids`) and new format (`saved_items`)
- Nullable foreign key ensures no data migration required

### Data Consistency
- Custom sizes belong to users, ensuring isolation
- Saved items validate uniqueness on `user_id` and `frame_sku_id` combination
- Deleting a custom size cascades properly due to foreign key constraints

## Files Modified

### Backend
- `db/migrate/20251107004042_add_custom_print_size_to_saved_items.rb` (new)
- `app/models/saved_item.rb`
- `app/controllers/saved_items_controller.rb`

### Frontend
- `app/javascript/components/ProductSelectionStep.js`
- `app/javascript/components/ProductBrowser.js`

## Testing Recommendations

1. **Saving Items**
   - Save item without custom size (standard flow)
   - Save item with custom size selected
   - Verify correct IDs are stored in database

2. **Loading Items**
   - Load saved items list with mix of standard and custom sizes
   - Verify custom sizes display with correct dimensions
   - Verify standard sizes display normally

3. **Selecting Items**
   - Select saved item without custom size
   - Select saved item with custom size
   - Verify correct data is passed to order configuration

4. **Edge Cases**
   - User deletes custom size that's referenced by saved item
   - User saves same frame SKU with different custom sizes
   - Verify uniqueness constraint still works correctly

## Future Enhancements

Potential improvements for consideration:

1. **Saved Item Management**
   - Allow updating custom size on existing saved item
   - Add ability to view/edit saved item notes or tags

2. **Custom Size Library**
   - Quick access to custom sizes from saved items view
   - Ability to apply custom size from one saved item to another

3. **Duplicate Detection**
   - Warn user if trying to save duplicate frame SKU with different custom size
   - Option to replace or keep both versions

## Conclusion

This implementation successfully resolves the issue where custom sizes were not being preserved in saved items. Users can now save products with custom dimensions and have those exact specifications restored when selecting the saved item later.

