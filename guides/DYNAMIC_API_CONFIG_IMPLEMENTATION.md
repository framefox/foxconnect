# Dynamic API Configuration Implementation

## Overview

Successfully replaced hardcoded API URLs and Shopify customer IDs in JavaScript components with a dynamic configuration system that uses country-specific settings based on the current user's profile.

## Problem Solved

Previously, three JavaScript files had hardcoded values:
- API URL: `http://dev.framefox.co.nz:3001`
- Shopify Customer ID: `123456789`
- Auth Token: `0936ac0193ec48f7f88d38c1518572a2e5f8a5c3`

These values are now dynamically loaded based on:
- The user's country setting (`current_user.country`)
- The user's ShopifyCustomer record for that country
- Environment variables for API authentication

## Implementation Details

### 1. Helper Method (`app/helpers/application_helper.rb`)

Added `framefox_api_config` method that:
- Gets the current user's country (defaults to "NZ" if not set)
- Loads country-specific configuration using `CountryConfig.for_country(country_code)`
- Falls back to NZ config if the country config doesn't exist
- Finds the user's ShopifyCustomer record for that country
- Returns a hash with:
  - `apiUrl`: Country-specific API URL + base path
  - `apiAuthToken`: From `ENV['FRAMEFOX_API_KEY']`
  - `shopifyCustomerId`: From user's ShopifyCustomer record
  - `countryCode`: The country code

### 2. Global JavaScript Configuration (`app/views/layouts/application.html.erb`)

Injected into the `<head>` section for authenticated users:
```erb
<% if current_user %>
  <script type="text/javascript">
    window.FramefoxConfig = <%= framefox_api_config.to_json.html_safe %>;
  </script>
<% end %>
```

This makes the configuration available globally as `window.FramefoxConfig`.

### 3. Updated JavaScript Components

#### ProductSelectModal.js
- **fetchProducts()**: Now uses `window.FramefoxConfig.apiUrl` and `window.FramefoxConfig.apiAuthToken`
- **fetchArtworks()**: Now uses `window.FramefoxConfig.shopifyCustomerId` for customer-specific image fetching
- Added validation to check configuration exists before making API calls

#### ArtworkSelectionStep.js
- **Uploader component**: Now uses dynamic values for:
  - `post_image_url`: Built from config values
  - `shopify_customer_id`: From `window.FramefoxConfig.shopifyCustomerId`
- Uses optional chaining (`?.`) for safe access

#### ProductSelectionStep.js
- **getApiUrl()**: Simplified to return `window.FramefoxConfig.apiUrl`
- Removed hardcoded country URL mapping
- Added warning if config is not available

## Configuration Flow

1. User logs in → Devise authenticates user
2. User navigates to any page → Layout loads
3. `framefox_api_config` helper is called
4. Helper reads:
   - `current_user.country` (e.g., "AU")
   - Country config from `config/countries/au.yml`
   - ShopifyCustomer record with `country_code: "AU"`
5. Configuration object is injected into page as JavaScript
6. React components access `window.FramefoxConfig` for API calls

## Country-Specific Behavior

### New Zealand Users (`country: "NZ"`)
- API URL: From `config/countries/nz.yml` → `api_url` + `api_base_path`
  - Development: `http://dev.framefox.co.nz:3001/api`
  - Production: `https://staging.framefox.co.nz/api`
- ShopifyCustomer: Record with `country_code: "NZ"`

### Australia Users (`country: "AU"`)
- API URL: From `config/countries/au.yml` → `api_url` + `api_base_path`
  - Development: `http://dev.framefox.com.au:3001/api`
  - Production: `https://staging.framefox.com.au/api`
- ShopifyCustomer: Record with `country_code: "AU"`

## Error Handling

All components now include validation:
- Check if `window.FramefoxConfig` exists
- Check if required properties are present
- Display user-friendly error messages
- Log warnings to console for debugging

## Testing Checklist

### Test Scenarios

1. **NZ User with ShopifyCustomer**
   - Verify API calls go to NZ endpoint
   - Verify correct ShopifyCustomer ID is used
   - Check browser console for `window.FramefoxConfig` values

2. **AU User with ShopifyCustomer**
   - Verify API calls go to AU endpoint
   - Verify correct ShopifyCustomer ID is used
   - Check browser console for `window.FramefoxConfig` values

3. **User without ShopifyCustomer**
   - Verify API calls still work for frame SKUs
   - Verify image upload shows appropriate error if customer ID is null
   - Check error handling displays correct message

4. **User without country set**
   - Verify defaults to NZ configuration
   - Check API calls work correctly

### How to Test

1. Open browser developer tools (Console tab)
2. Log in as a user
3. Type `window.FramefoxConfig` in console to see current config
4. Navigate to product variants page
5. Click "Choose product & image"
6. Monitor Network tab for API requests
7. Verify URLs match the expected country endpoint

### Expected Console Output

```javascript
window.FramefoxConfig
// Output:
{
  apiUrl: "http://dev.framefox.co.nz:3001/api",
  apiAuthToken: "0936ac0193ec48f7f88d38c1518572a2e5f8a5c3",
  shopifyCustomerId: 123456789,
  countryCode: "NZ"
}
```

## Files Modified

1. `app/helpers/application_helper.rb` - Added `framefox_api_config` method
2. `app/views/layouts/application.html.erb` - Injected config script
3. `app/javascript/components/ProductSelectModal.js` - Dynamic API URLs
4. `app/javascript/components/ArtworkSelectionStep.js` - Dynamic config
5. `app/javascript/components/ProductSelectionStep.js` - Dynamic API URL

## Benefits

- **Country-Specific**: Automatically uses correct API endpoint per user's country
- **Maintainable**: Configuration managed in one place (helper method)
- **Secure**: Auth token from environment variables, not hardcoded
- **Flexible**: Easy to add new countries by updating config files
- **User-Aware**: Each user gets their own ShopifyCustomer ID
- **Error-Resilient**: Graceful fallbacks and user-friendly error messages

## Future Enhancements

Consider adding:
- Country selector UI to allow users to switch contexts
- Caching of ShopifyCustomer lookups for performance
- Admin interface to manage user-country associations
- Multi-country support for users operating in multiple regions

