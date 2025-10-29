# Country Configuration System Implementation Summary

## Overview

Successfully implemented a country-based configuration system to support multiple markets (NZ and AU) with different API endpoints, currencies, and fulfillment rules.

## What Was Implemented

### 1. Country Configuration Files

**Location:** `config/countries/`

Created YAML configuration files for each supported country:

- `nz.yml` - New Zealand configuration
- `au.yml` - Australia configuration

Each file contains environment-specific settings:

- `api_url` - Production API base URL
- `api_base_path` - API path (`/api`)
- `shopify_domain` - Country-specific Shopify store
- `shopify_access_token` - Shopify API credentials
- `currency` - Currency code (NZD, AUD)
- `country_code` - ISO 3166-1 alpha-2 code
- `country_name` - Human-readable country name

### 2. Configuration Loader

**File:** `config/initializers/country_config.rb`

Created `CountryConfig` module with:

- `for_country(country_code)` - Load config for specific country
- `supported_countries` - Returns `['NZ', 'AU']`
- `supported?(country_code)` - Check if country is supported
- Caches loaded configurations for performance

### 3. Database Changes

**Migration:** `20251014220703_add_country_code_to_orders_and_variant_mappings.rb`

**Orders table:**

- Added `country_code` (string, 2 chars)
- Added index on `country_code`

**Variant mappings table:**

- Added `country_code` (string, 2 chars, not null, default: 'NZ')
- Added composite index on `[product_variant_id, country_code]`
- **Updated unique constraint:** Now one default per country per variant
  - Removed: `index_variant_mappings_on_product_variant_id_and_is_default`
  - Added: `idx_variant_mappings_default_per_country` on `[product_variant_id, country_code, is_default]`

This allows products to have different variant mappings for NZ and AU markets.

### 4. Model Updates

#### Order Model (`app/models/order.rb`)

**Added:**

- `before_validation :set_country_from_shipping_address` callback
- Country code validation (must be NZ or AU, can be nil)
- `country_config` method - Returns country-specific configuration
- `fulfillable_country?` - Check if country is supported
- `country_name` - Human-readable country name

**Behavior:**

- Country code automatically set from shipping address on create
- Prevents saving orders with unsupported countries

#### VariantMapping Model (`app/models/variant_mapping.rb`)

**Added:**

- Country code presence validation
- Country code must be NZ or AU
- `country_config` method
- `country_name` method
- **Updated uniqueness validation:** `is_default` now scoped to `[product_variant_id, country_code]`

### 5. Service Updates

#### ImportOrderService (`app/services/import_order_service.rb`)

**Changes:**

- Imports shipping address before validating order
- Sets `country_code` from `shipping_address.country_code`
- Validates country is supported (NZ or AU)
- **Raises error** for unsupported countries with clear message
- Applied to both `import_order` and `resync_order_data` methods

**Error handling:**

```ruby
raise StandardError, "Unsupported country: #{order.country_code}. Only NZ and AU orders can be fulfilled."
```

#### OrderProductionService (`app/services/order_production_service.rb`)

**Changes:**

- `api_url` method now uses `order.country_config`
  - NZ orders → `http://dev.framefox.co.nz:3001`
  - AU orders → `http://dev.framefox.com.au:3001`
- `shopify_graphql_request` uses country-specific Shopify credentials
  - NZ orders → NZ Shopify store and token
  - AU orders → AU Shopify store and token

### 6. View Updates

#### Orders Show Page (`app/views/orders/show.html.erb`)

**Added:**

- Country badge display in order header (shows country code with globe icon)
- Pass `apiUrl` and `countryCode` to all OrderItemCard components:
  - Unfulfilled items
  - Fulfilled items
  - Draft items
  - Removed items

**Props passed to React:**

```ruby
apiUrl: @order.country_config ? "#{@order.country_config['api_url']}#{@order.country_config['api_base_path']}" : nil,
countryCode: @order.country_code,
```

### 7. Frontend Component Updates

#### OrderItemCard (`app/javascript/components/OrderItemCard.js`)

**Added props:**

- `apiUrl` - Country-specific API URL from backend
- `countryCode` - Order's country code

**Passes to ProductSelectModal:**

- Forwards `apiUrl` and `countryCode` to modal

#### ProductSelectModal (`app/javascript/components/ProductSelectModal.js`)

**Added props:**

- `apiUrl` - Country-specific API URL
- `countryCode` - Country code for the order

**Passes to child components:**

- `ProductSelectionStep` receives `apiUrl` and `countryCode`
- `CropStep` receives `countryCode`

#### ProductSelectionStep (`app/javascript/components/ProductSelectionStep.js`)

**Added props:**

- `apiUrl` - Country-specific API URL (ready to use for frame SKU fetching)
- `countryCode` - Display country information

**Future use:**

- Will use `apiUrl` to fetch frame SKUs from correct production system
- Country selector UI can be added here for display/confirmation

## Business Rules Enforced

1. **Order Country Detection:**

   - Automatically set from shipping address country code
   - Set during order import from Shopify
   - Converted to uppercase (e.g., "nz" → "NZ")

2. **Supported Countries:**

   - Only NZ and AU orders can be fulfilled
   - Orders from other countries are rejected with clear error message
   - Validation happens at import time

3. **Variant Mappings:**

   - Each variant mapping is country-specific
   - A product variant can have one default mapping per country
   - Example: Product can have NZ frame and AU frame configurations

4. **API Routing:**

   - NZ orders use NZ production API
   - AU orders use AU production API
   - Shopify operations use country-specific credentials

5. **Currency Handling:**
   - Order currency comes from Shopify order
   - Country config includes currency (NZD for NZ, AUD for AU)
   - Production costs populated in order's currency

## Data Flow

### Order Import

1. Shopify order imported via GraphQL
2. Shipping address created
3. Country code extracted from `shipping_address.country_code`
4. Country validated (must be NZ or AU)
5. Order saved with country code
6. Order items created

### Product Selection (Future Enhancement)

1. User opens product selection modal
2. Frontend receives `apiUrl` from backend (already country-specific)
3. User selects product type
4. Frame SKUs fetched from correct production API
5. Variant mapping created with country code

### Order Production

1. Order sent to production
2. Correct API URL selected based on country
3. Draft order created in country-specific Shopify store
4. Production costs saved in order's currency

## Environment Variables

### Required Environment Variables

```bash
# New Zealand
remote_shopify_domain_nz=your-nz-shop.myshopify.com
remote_shopify_access_token_nz=your_nz_token

# Australia
remote_shopify_domain_au=your-au-shop.myshopify.com
remote_shopify_access_token_au=your_au_token

# Production URLs (production environment only)
NZ_PRODUCTION_API_URL=https://api.framefox.co.nz
AU_PRODUCTION_API_URL=https://api.framefox.com.au
```

## Testing Checklist

- [ ] Import NZ order (country_code = 'NZ')
- [ ] Import AU order (country_code = 'AU')
- [ ] Try importing order from unsupported country (should fail with error)
- [ ] Verify NZ order uses NZ API URL
- [ ] Verify AU order uses AU API URL
- [ ] Send NZ order to production (uses NZ Shopify store)
- [ ] Send AU order to production (uses AU Shopify store)
- [ ] Create variant mapping for NZ product
- [ ] Create variant mapping for AU product
- [ ] Verify one default per country per variant
- [ ] Check country badge displays in order view
- [ ] Verify apiUrl passed to frontend components

## Migration Status

✅ Migration run successfully:

- `country_code` added to `orders` table
- `country_code` added to `variant_mappings` table
- Unique constraint updated for country-specific defaults
- All existing variant mappings default to 'NZ'

## Known Limitations & Future Work

1. **Country Selector UI:**

   - Props are passed to ProductSelectionStep
   - UI for country selection not yet implemented
   - Will allow users to choose NZ or AU fulfillment

2. **Existing Orders:**

   - Orders without shipping address will have `nil` country_code
   - These orders cannot be sent to production
   - May need data migration for historical orders

3. **Product Selection:**

   - Frame SKU fetching needs to use passed `apiUrl`
   - Current implementation may still use hardcoded URL

4. **Multi-Country Products:**
   - UI for managing multiple country mappings per product not yet built
   - Backend supports it (one default per country)
   - Future: Add country tabs to variant mapping management

## Files Modified

### Configuration

- `config/countries/nz.yml` (new)
- `config/countries/au.yml` (new)
- `config/initializers/country_config.rb` (new)

### Database

- `db/migrate/20251014220703_add_country_code_to_orders_and_variant_mappings.rb` (new)

### Models

- `app/models/order.rb`
- `app/models/variant_mapping.rb`

### Services

- `app/services/import_order_service.rb`
- `app/services/order_production_service.rb`

### Views

- `app/views/orders/show.html.erb`

### JavaScript Components

- `app/javascript/components/OrderItemCard.js`
- `app/javascript/components/ProductSelectModal.js`
- `app/javascript/components/ProductSelectionStep.js`

## Success Criteria Met

✅ Country configuration files created for NZ and AU
✅ Configuration loader with caching implemented
✅ Database schema updated with country codes
✅ Order model automatically detects country from shipping address
✅ Unsupported countries rejected with clear error
✅ Variant mappings support country-specific configurations
✅ Production service uses country-specific APIs and Shopify credentials
✅ Frontend receives country configuration from backend
✅ Country badge displayed in order views
✅ No linter errors in any modified files

## Next Steps

1. **Test the Import Flow:**

   - Import orders from NZ and AU
   - Verify country codes are set correctly
   - Test rejection of unsupported countries

2. **Test Production Flow:**

   - Send NZ order to production
   - Send AU order to production
   - Verify correct APIs are used

3. **Implement Country Selector UI:**

   - Add country selector to ProductSelectionStep
   - Show country-specific frame SKUs
   - Save country code with variant mapping

4. **Add Multi-Country Management:**
   - UI for viewing/editing mappings per country
   - Bulk operations for creating country variants
   - Country-specific default management
