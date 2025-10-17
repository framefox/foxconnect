# Custom Print Size Feature Implementation

## Overview

Added a custom print size feature to the Product Selection modal that allows users to enter custom dimensions (width, height, unit) and match them to available frame sizes via API. The custom size then locks the print size filter and automatically searches for matching products.

## Changes Made

### 1. New Component: CustomPrintSizeModal.js

**Location:** `/app/javascript/components/CustomPrintSizeModal.js`

A modal component that provides:

- Width and height input fields (numeric, with decimal support)
- Unit selection (cm, mm, in) via radio buttons styled as toggle buttons
- Form validation for positive numbers
- API integration to match custom dimensions to frame sizes
- Error handling and display
- Loading state with spinner
- Modal backdrop and close functionality

**API Endpoint:** `GET /api/frame_sku_sizes/match?width={width}&height={height}&unit={unit}`

**Expected Response:**

```json
{
  "frame_sku_size": {
    "id": 123,
    "size_description": "30×40cm"
  }
}
```

**Output:** Returns an object containing:

- `frame_sku_size_id`: ID to use for filtering
- `frame_sku_size_title`: Display title from API
- `user_width`, `user_height`, `user_unit`: User's entered dimensions

### 2. ProductSelectionStep.js Integration

**Location:** `/app/javascript/components/ProductSelectionStep.js`

#### State Management

Added two new state variables:

- `customSizeModalOpen` - Controls modal visibility
- `customSizeData` - Stores custom size information when locked

#### New Handler Functions

- `handleOpenCustomSizeModal()` - Opens the custom size modal
- `handleCloseCustomSizeModal()` - Closes the custom size modal
- `handleCustomSizeSubmit(data)` - Processes custom size submission:
  - Stores custom size data
  - Updates selected options with frame_sku_size_id
  - Closes modal
  - Automatically triggers search with new options
- `handleClearCustomSize()` - Clears custom size data and reverts to dropdown

#### Print Size Section Updates

Modified the Print Size section to include:

**Unlocked State:**

- "Custom" link displayed above the Print Size label
- Standard dropdown showing all available sizes

**Locked State (when custom size is set):**

- Display format: `{width}×{height}{unit} (Charged as {api_title})`
  - Example: "30×40cm (Charged as 16x20")"
- "Clear Size" link to unlock and revert to dropdown
- Gray background to indicate locked state
- No "Custom" link visible

#### Modal Integration

Added CustomPrintSizeModal component to the render with:

- `isOpen` prop from state
- `onClose` handler
- `onSubmit` handler
- `apiUrl` from `getApiUrl()` function

## User Flow

1. User clicks "Custom" link above Print Size dropdown
2. Modal opens with width/height inputs and unit selector
3. User enters dimensions and selects unit (default: cm)
4. User clicks "Next" button
5. API call is made to match dimensions
6. On success:
   - Modal closes
   - Custom size is displayed in locked format
   - Search automatically runs with the matched frame_sku_size_id
7. User can click "Clear Size" to unlock and return to dropdown

## Error Handling

- Client-side validation for empty or non-positive numbers
- API error handling with user-friendly messages
- Error display within modal (keeps modal open)
- Loading state prevents multiple submissions

## Styling

- Clean, minimal modal design matching application style guidelines
- Uses slate color palette for consistency (slate-900, slate-100, slate-600, etc.)
- Lighter backdrop (slate-900 with 40% opacity) instead of solid black
- Compact form layout with proper labels
- Responsive layout with centered modal
- Standard loading spinner icon (fa-solid fa-spinner-third fa-spin)
- Focus states with ring-2 ring-slate-950 for accessibility
- Hover states for all interactive elements

## API Requirements

The feature expects the API endpoint `/api/frame_sku_sizes/match` to:

- Accept query parameters: `width`, `height`, `unit`
- Return a JSON response with `frame_sku_size` object containing:
  - `id` - The frame size ID
  - `size_description` - Display name for the size (e.g., "30×40cm")
- Return appropriate error status codes for invalid dimensions or no matches

## Custom Size Data Flow Implementation

### Overview

Custom dimensions entered by users flow through the entire product selection and cropping process, ultimately being saved to the `variant_mapping` with the user's specified dimensions rather than the frame SKU's default dimensions.

### Data Flow

```
ProductSelectionStep (customSizeData stored)
  ↓ User selects product
onProductSelect(product, customSizeData)
  ↓
ProductSelectModal (receives and stores customSizeData)
  ↓ Advances to crop step
CropStep (displays custom dimensions, uses for aspect ratio)
  ↓ User saves crop
handleSaveCrop (includes custom width/height/unit in payload)
  ↓
VariantMapping (saves custom dimensions, skips auto-calculation)
```

### Implementation Details

#### 1. ProductSelectionStep.js

- Modified `onProductSelect` call to pass `customSizeData` as second parameter
- Custom size data includes: `user_width`, `user_height`, `user_unit`, `frame_sku_size_id`, `frame_sku_size_title`

#### 2. ProductSelectModal.js

- Added `customSizeData` state variable
- Updated `handleProductSelect` to accept and store custom size parameter
- Modified `getCropAspectRatio()` to calculate aspect ratio using custom dimensions when available
- Updated `handleSaveCrop` to spread custom dimensions into variant_mapping payload when present
- Passes `customSizeData` prop to CropStep component

#### 3. CropStep.js

- Added `customSizeData` parameter to function signature
- Updated Frame Size display to show custom dimensions when available
- Displays custom size in blue with "(Custom size, charged as [API size])" indicator

#### 4. VariantMapping Model

- Modified `calculate_dimensions_from_frame_sku` callback to skip calculation if width/height/unit are already explicitly set
- This allows custom dimensions to override automatic calculation while maintaining backward compatibility

### Benefits

1. **User Intent Preserved**: Custom dimensions entered by users are maintained throughout the entire flow
2. **Clear Visual Feedback**: Crop step clearly shows custom size with visual indicator
3. **Accurate Billing**: Frame is charged at the matched size from API
4. **Correct Dimensions**: Variant mapping stores the user's custom dimensions for production
5. **Backward Compatible**: Existing flows without custom sizes continue to work with automatic dimension calculation
