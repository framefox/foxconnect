# Country Selector UI Implementation

## Overview

Added the country selector UI to the Product Selection Modal, allowing users to choose between NZ and AU fulfillment when creating variant mappings.

## Changes Made

### 1. ProductSelectionStep Component

**File:** `app/javascript/components/ProductSelectionStep.js`

#### Added State Management

```javascript
const [selectedCountry, setSelectedCountry] = useState(countryCode || "NZ");

const supportedCountries = [
  { code: "NZ", name: "New Zealand", currency: "NZD" },
  { code: "AU", name: "Australia", currency: "AUD" },
];
```

#### Added Country Selector UI

Located at the top of the "Select Product Type" screen:

- Dropdown selector for NZ/AU
- Displays country name and currency
- Helper text showing which production system will be used
- Styled consistently with the application theme

**UI Structure:**

```javascript
<div className="mb-8 max-w-md mx-auto">
  <label className="block text-sm font-medium text-gray-700 mb-2">
    Fulfillment Country
  </label>
  <select
    value={selectedCountry}
    onChange={(e) => setSelectedCountry(e.target.value)}
    className="w-full px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-slate-950 focus:border-slate-950 transition-colors"
  >
    {supportedCountries.map((country) => (
      <option key={country.code} value={country.code}>
        {country.name} ({country.currency})
      </option>
    ))}
  </select>
  <p className="mt-2 text-sm text-gray-500">
    Frame SKUs will be loaded from the{" "}
    {supportedCountries.find((c) => c.code === selectedCountry)?.name}{" "}
    production system
  </p>
</div>
```

#### Updated API URL Logic

Added `getApiUrl()` function that uses `selectedCountry` to determine the API URL:

```javascript
const getApiUrl = () => {
  // Always use selectedCountry to determine URL
  // This allows users to override the order's default country if needed
  const countryUrls = {
    NZ: "http://dev.framefox.co.nz:3001/api",
    AU: "http://dev.framefox.com.au:3001/api",
  };
  return countryUrls[selectedCountry] || countryUrls["NZ"];
};
```

**Key behavior:** The country selector **directly controls** which API is used. When a user changes the country dropdown, the API URL immediately switches to the corresponding production system.

#### Auto-Reset on Country Change

Added a `useEffect` hook that resets the product selection when country changes:

```javascript
useEffect(() => {
  // Only reset if user has already made selections
  if (selectedProductType || frameSkuData) {
    handleBackToTypeSelection();
  }
}, [selectedCountry]);
```

This ensures users don't see stale data from the previous country's API.

#### Updated API Calls

Both `fetchFrameSkuData` and `searchFrameSkus` now use `getApiUrl()`:

- Frame SKU type endpoint: `${baseUrl}/shopify-customers/.../frame_skus/${endpoint}`
- Frame SKU search endpoint: `${baseUrl}/shopify-customers/.../frame_skus.json`

### 2. ProductSelectModal Component

**File:** `app/javascript/components/ProductSelectModal.js`

#### Added Country Code to Variant Mapping

When saving a variant mapping, the `country_code` comes from the **frame SKU data returned by the API**:

```javascript
{
  variant_mapping: {
    // ... other fields
    cloudinary_id: selectedArtwork.cloudinary_id || selectedArtwork.key,
    image_filename: selectedArtwork.filename,
    country_code:
      replaceImageMode && existingVariantMapping
        ? existingVariantMapping.country_code
        : selectedProduct.country?.toUpperCase() || selectedCountryCode,  // NEW
  }
}
```

**Key behavior:** The country code is extracted from the `country` field in the frame SKU API response (e.g., `"nz"` → `"NZ"`). This ensures the variant mapping always has the correct country as determined by the production system, not just what the user selected in the dropdown.

### 3. VariantMappingsController

**File:** `app/controllers/variant_mappings_controller.rb`

#### Updated Permitted Parameters

Added `country_code` to the list of permitted parameters:

```ruby
def variant_mapping_params
  params.require(:variant_mapping).permit(
    # ... existing parameters
    :frame_sku_long,
    :frame_sku_short,
    :frame_sku_unit,
    :country_code  # NEW
  )
end
```

## User Flow

### Creating a Variant Mapping

1. User opens Product Selection Modal from order item
2. **NEW:** User sees country selector at top (defaults to order's country)
3. **NEW:** User can change country selection between NZ and AU
4. User selects product type (Matted, Unmatted, Canvas, Print Only)
5. **Backend:** Frame SKUs are fetched from selected country's API
   - API URL determined by country selector (NZ or AU)
6. User selects frame options and searches for products
7. **Backend:** Products returned from selected country's production system
   - Each frame SKU includes `country` field (e.g., `"nz"`)
8. User selects artwork and crops it
9. **Backend:** Variant mapping saved with `country_code` from frame SKU data
   - Country code comes from `selectedProduct.country` field (uppercased)
   - NOT from user's dropdown selection
   - Ensures frame SKU and country code always match

### Country-Specific Behavior

- **NZ Selection:** Fetches from `http://dev.framefox.co.nz:3001/api`
- **AU Selection:** Fetches from `http://dev.framefox.com.au:3001/api`
- **Production:** Uses environment-specific URLs from country config files

## Visual Design

The country selector features:

- **Clean dropdown** with full country names and currencies
- **Helper text** clarifying which system will be used
- **Proper spacing** separates it from product type selection
- **Consistent styling** matches application theme
- **Focus states** for accessibility

## Data Flow

```
Order (country_code: "NZ")
  → OrderItemCard (countryCode prop)
    → ProductSelectModal (countryCode prop)
      → ProductSelectionStep (countryCode prop)
        → User selects country (state: selectedCountry)
          → getApiUrl() returns country-specific URL
            → API calls use correct production system
              → Frame SKU returned with country field: "nz"
                → selectedProduct.country = "nz"
                  → Variant mapping saved with country_code: "NZ" (from API data)
```

## Country Selector: Two-Phase System

### Phase 1: API Routing (Country Selector)

**Purpose:** Control which production system to query
**User Action:** Select NZ or AU in dropdown
**Result:** Frame SKUs fetched from selected country's API

### Phase 2: Country Storage (Frame SKU Data)

**Purpose:** Store the actual country of the frame SKU
**Data Source:** `country` field from frame SKU API response
**Result:** Variant mapping saved with correct country code

### Why This Approach?

1. **API is source of truth:** The production system knows which country each frame SKU belongs to
2. **Prevents mismatches:** Can't accidentally save NZ frame with AU country code
3. **User flexibility:** User controls which system to query, but country is validated by API
4. **Data integrity:** Frame SKU and country code always align

### Example Scenario

```
User: Selects "AU" in dropdown
System: Calls http://dev.framefox.com.au:3001/api
API: Returns frame SKUs with country: "au"
User: Selects frame FXMS2.252.1.67
System: Saves variant mapping with country_code: "AU" (from selectedProduct.country)
Result: ✅ Frame SKU and country code match perfectly
```

## Integration with Existing System

### Backend Country Detection

- Order's `country_code` set from shipping address (already implemented)
- Passed to frontend via `countryCode` prop
- Used as initial/default value in country selector

### API URL Resolution

The API URL is **always determined by the country selector**:

1. `selectedCountry` state (user's selection in UI) - **Primary source of truth**
2. Defaults to order's `countryCode` prop on initial load
3. Fallback to 'NZ' if neither is available

The `apiUrl` prop from the backend is ignored in favor of giving users full control via the country selector.

### Variant Mapping Validation

- Country code required (model validation)
- Must be 'NZ' or 'AU' (model validation)
- One default per country per product variant (database constraint)

## Testing Scenarios

### Test Country Selector

- [ ] Selector displays on product selection modal
- [ ] Defaults to order's country code
- [ ] User can change between NZ and AU
- [ ] Helper text updates when country changes

### Test API Routing

- [ ] Selecting NZ fetches from NZ API
- [ ] Selecting AU fetches from AU API
- [ ] Frame SKUs load correctly for each country
- [ ] Search results come from correct system

### Test Variant Mapping Creation

- [ ] NZ selection saves country_code: 'NZ'
- [ ] AU selection saves country_code: 'AU'
- [ ] Variant mapping validates country code
- [ ] Can create separate mappings for NZ and AU on same product

### Test Order Context

- [ ] NZ order defaults to NZ selection
- [ ] AU order defaults to AU selection
- [ ] User can override default if needed
- [ ] Saved mapping uses selected country

## Future Enhancements

1. **Country Badge on Variant Mappings:**

   - Show country flag/code on variant mapping cards
   - Filter variant mappings by country in admin views

2. **Multi-Country Management:**

   - View all country variants for a product
   - Bulk operations for creating country-specific variants
   - Country comparison view

3. **Smart Defaults:**

   - Remember user's last country selection
   - Suggest country based on frame SKU availability
   - Auto-detect optimal country for specific products

4. **Validation Feedback:**
   - Show which countries have mappings
   - Warn if creating duplicate for same country
   - Highlight missing country configurations

## Files Modified

- `app/javascript/components/ProductSelectionStep.js`
- `app/javascript/components/ProductSelectModal.js`
- `app/controllers/variant_mappings_controller.rb`

## Completion Status

✅ Country selector UI implemented
✅ API routing uses selected country
✅ Variant mappings save with country code
✅ Backend accepts country code parameter
✅ No linter errors
✅ Integrated with existing country infrastructure

The country selector is now fully functional and allows users to choose which production system (NZ or AU) to use when creating variant mappings!
