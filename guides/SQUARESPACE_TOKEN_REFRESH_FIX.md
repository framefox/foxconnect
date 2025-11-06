# Squarespace Order Import Fixes

## Issues Fixed

### 1. Authentication Error
When using `SquarespaceImportOrderService`, authentication errors were occurring:
```
Failed to fetch order from Squarespace: Authentication failed: 
{ "type" : "AUTHORIZATION_ERROR", "subtype" : null, "message" : "You are not authorized to do that." }
```

### 2. Missing Method Error
After fixing authentication, a second error appeared:
```
An error occurred while importing the order: undefined method `country_name' for module CountryConfig
```

### 3. Database Constraint Violation
After fixing the missing method, a third error appeared:
```
PG::CheckViolation: ERROR: new row for relation "shipping_addresses" violates check constraint "ship_addr_province_code_len"
DETAIL: Failing row contains (...province: Te Awanga, province_code: Te Awanga...)
```

### 4. Order Activity Validation Error
After fixing the database constraint, a fourth error appeared:
```
Order import failed: Validation failed: Title can't be blank, Occurred at can't be blank
```

## Root Causes

### Authentication Error
Several methods in `SquarespaceApiService` were not checking if the access token was expired before making API requests. This meant that:
1. Expired tokens were being used for API calls
2. The automatic token refresh mechanism wasn't being triggered
3. API requests would fail with authorization errors

### Missing Method Error
The `CountryConfig` module was missing a class method `country_name` that could look up country names from country codes. The module had the data in the YAML config files, but no method to retrieve it.

### Database Constraint Violation
The `province_code` field in the `shipping_addresses` table has a check constraint requiring it to be 0, 2, or 3 characters (standard state/province codes like "CA", "NSW", "QLD"). 

The Squarespace import was incorrectly using `address_data["state"]` for both `province` AND `province_code`. For New Zealand addresses (which don't have states), Squarespace was returning locality/suburb names like "Te Awanga" in the state field, which are too long for `province_code`.

### Order Activity Validation Error
The `OrderActivity` model requires `title` and `occurred_at` fields to be present. The Squarespace import was directly creating an activity without these required fields:

```ruby
# Old code - missing required fields
order.order_activities.create!(
  activity_type: "order_imported",
  description: "Order imported from Squarespace",
  metadata: { source: "squarespace", order_number: order_data["orderNumber"] }
)
```

## Solutions

### Fix 1: Token Refresh for API Calls
Updated the following methods in `app/services/squarespace_api_service.rb` to call `ensure_valid_token!` before making API requests:

- `get_products` - Fetches all products
- `get_product` - Fetches a specific product
- `get_orders` - Fetches all orders
- `get_order` - Fetches a specific order

### Fix 2: Add Country Name Lookup Method
Added a new `country_name` class method to `CountryConfig` in `config/initializers/country_config.rb`:

```ruby
def country_name(country_code)
  return country_code if country_code.blank?
  
  config = for_country(country_code)
  config&.dig("country_name") || country_code
rescue => e
  Rails.logger.warn "Failed to get country name for #{country_code}: #{e.message}"
  country_code
end
```

This method:
- Loads the country config for the given code (e.g., "NZ" or "AU")
- Extracts the `country_name` value (e.g., "New Zealand" or "Australia")
- Falls back to the country code if the config doesn't exist or lacks the field
- Handles errors gracefully by logging a warning and returning the original code

### Fix 3: Smart Province Code Handling
Updated the `import_shipping_address` method in `app/services/squarespace_import_order_service.rb` to intelligently handle state/province data:

```ruby
# Extract state/province data
state_value = address_data["state"]

# Determine if state is a valid province code (2-3 characters) or full name
# Province codes should be 2-3 characters (e.g., "CA", "NSW", "QLD")
# For countries without states (like NZ), this might be a suburb/locality
province_code = if state_value.present? && state_value.length.between?(2, 3) && state_value.match?(/^[A-Z]+$/i)
  state_value.upcase
else
  nil
end
```

This fix:
- Sets `province` to the full state/locality value from Squarespace (can be any length)
- Only sets `province_code` if the value is 2-3 characters and all letters (valid state code)
- Sets `province_code` to `nil` for countries without states or when Squarespace sends locality names
- Prevents database constraint violations

**Examples:**
- "NSW" → `province: "NSW"`, `province_code: "NSW"` ✅
- "CA" → `province: "CA"`, `province_code: "CA"` ✅
- "Te Awanga" → `province: "Te Awanga"`, `province_code: nil` ✅
- "123" → `province: "123"`, `province_code: nil` (not all letters) ✅

### Fix 4: Use OrderActivityService for Activity Logging
Updated the import service to use the proper `OrderActivityService` for logging order import activities:

```ruby
# New code - uses the service with all required fields
OrderActivityService.new(order: order).log_order_imported(
  source_platform: "squarespace",
  external_id: order_data["id"]
)
```

The `OrderActivityService.log_order_imported` method:
- Automatically sets `title` to "Order imported"
- Automatically sets `description` to "Order imported from Squarespace"
- Automatically sets `occurred_at` to current time
- Properly structures the metadata with platform info and timestamps
- Ensures all validations pass

### Token Refresh Flow
1. `ensure_valid_token!` checks if the access token is expired or expiring within 10 seconds
2. If expired, it checks if the refresh token is still valid
3. If the refresh token is valid, it calls `refresh_store_token!`
4. The store is updated with new access and refresh tokens
5. The API request proceeds with the fresh token

### Improved Error Handling
Enhanced error messages for common scenarios:
- **Expired refresh token**: "Refresh token has expired. Store needs to be reconnected."
- **Missing refresh token**: "No refresh token available. Store needs to be reconnected."
- **Token refresh failure**: Includes the specific error message from Squarespace

## What This Fixes
✅ Automatic token refresh for order imports  
✅ Automatic token refresh for product syncs  
✅ Better error messages when reconnection is needed  
✅ Prevents authorization errors from expired tokens  
✅ Country name lookup for shipping addresses (NZ → "New Zealand", AU → "Australia")  
✅ Graceful fallback when country configs are missing  
✅ Smart province/state code handling for international addresses  
✅ Prevents database constraint violations on `province_code`  
✅ Correctly handles NZ addresses without states  
✅ Proper order activity logging with all required fields  
✅ Order import activities now show in order timeline  

## If You Still Get Authorization Errors

If you continue to see authorization errors after this fix, it likely means:

### 1. Refresh Token Has Expired
**Symptom**: Error message says "Refresh token has expired"  
**Solution**: Reconnect the Squarespace store

1. Go to the store settings in the admin panel
2. Click "Reconnect" or "Disconnect" and then reconnect
3. Complete the OAuth flow again

### 2. OAuth Scopes Are Insufficient
**Symptom**: Consistent authorization errors even with fresh tokens  
**Solution**: Check that your Squarespace OAuth application has the required scopes:
- `website.orders` - For reading order data
- `website.orders.write` - For creating fulfillments
- `website.products` - For reading product data
- `website.products.write` - For updating product images

To fix:
1. Go to your Squarespace Developer Account
2. Update your OAuth application's scopes
3. Reconnect all stores to get tokens with the new scopes

### 3. Store Was Disconnected in Squarespace
**Symptom**: Authorization errors for a specific store  
**Solution**: The store owner may have revoked access. Reconnect the store.

## Testing
To verify the fixes are working:

1. **Check token expiration in Rails console**:
```ruby
store = Store.find_by(platform: 'squarespace')
puts "Access token expires at: #{store.squarespace_token_expires_at}"
puts "Refresh token expires at: #{store.squarespace_refresh_token_expires_at}"
puts "Token expired? #{store.squarespace_token_expires_at < Time.current}"
```

2. **Manually test order import**:
```ruby
store = Store.find_by(platform: 'squarespace')
order_id = "YOUR_ORDER_ID" # Get from Squarespace
service = SquarespaceImportOrderService.new(store: store, order_id: order_id)
order = service.call

# Check the imported shipping address
address = order.shipping_address
puts "Province: #{address.province}"
puts "Province code: #{address.province_code.inspect}"
puts "Country: #{address.country}"
puts "Country code: #{address.country_code}"
```

3. **Test automatic refresh**:
```ruby
# Temporarily set token to expire soon (in Rails console)
store = Store.find_by(platform: 'squarespace')
store.update(squarespace_token_expires_at: 5.seconds.from_now)

# Wait 6 seconds, then try to fetch data
sleep 6
store.squarespace_api_client.get_orders
# Should see log: "Squarespace access token expired or expiring soon, refreshing..."
```

4. **Test province code validation**:
```ruby
# Create a test shipping address with various province values
test_cases = [
  { state: "NSW", expected_code: "NSW" },
  { state: "CA", expected_code: "CA" },
  { state: "Te Awanga", expected_code: nil },
  { state: "123", expected_code: nil },
  { state: "", expected_code: nil }
]

test_cases.each do |test|
  state_value = test[:state]
  province_code = if state_value.present? && state_value.length.between?(2, 3) && state_value.match?(/^[A-Z]+$/i)
    state_value.upcase
  else
    nil
  end
  
  puts "#{test[:state].inspect} -> #{province_code.inspect} (expected: #{test[:expected_code].inspect}) #{province_code == test[:expected_code] ? '✅' : '❌'}"
end
```

## Technical Details

### Token Expiration Times
Squarespace tokens have the following typical lifetimes:
- **Access tokens**: ~30 minutes
- **Refresh tokens**: ~180 days

Squarespace uses one-time refresh tokens, meaning:
- Each time you refresh the access token, you get a new refresh token
- The old refresh token becomes invalid
- Always store both the new access token and new refresh token

### Database Constraints
The `shipping_addresses` table has a check constraint on `province_code`:
```sql
char_length(province_code::text) = ANY (ARRAY[0, 2, 3])
```

This means `province_code` must be:
- Empty/null (0 characters)
- A 2-character code (e.g., "CA", "NY", "QLD")
- A 3-character code (e.g., "NSW", "ACT")

The constraint exists because `province_code` should only contain ISO standard state/province codes, not full names or locality names.

### International Address Handling
Different countries handle provinces/states differently:

**Countries with states (e.g., USA, Australia):**
- Squarespace sends proper state codes: "CA", "NSW", "QLD"
- Our code stores them in both `province` and `province_code`

**Countries without states (e.g., New Zealand):**
- Squarespace may send locality/suburb names: "Te Awanga", "Auckland"
- Our code stores them in `province` but sets `province_code` to `nil`
- This prevents constraint violations and accurately represents the data

### Best Practices (Already Implemented)
✅ Check token expiration before API calls  
✅ Use 10-second buffer before expiration (Squarespace recommendation)  
✅ Store both access and refresh tokens with expiration times  
✅ Update refresh token after each refresh (they're one-time use)  
✅ Provide clear error messages for reconnection scenarios  
✅ Validate province codes match expected format before storing  
✅ Gracefully handle countries without states  

## Related Files
- `app/services/squarespace_api_service.rb` - Main API client (token refresh fix)
- `app/services/squarespace_import_order_service.rb` - Order import service (province code & activity logging fixes)
- `app/services/order_activity_service.rb` - Order activity logging service
- `app/models/order_activity.rb` - Order activity model with validations
- `config/initializers/country_config.rb` - Country configuration module (added country_name method)
- `config/countries/nz.yml` - New Zealand country config
- `config/countries/au.yml` - Australia country config
- `app/models/shipping_address.rb` - Shipping address model
- `app/models/concerns/squarespace_integration.rb` - Store integration methods
- `app/models/store.rb` - Store model with token fields

## Database Fields
The following fields on the `stores` table support token management:
- `squarespace_token` - Current access token
- `squarespace_refresh_token` - Current refresh token (one-time use)
- `squarespace_token_expires_at` - When the access token expires
- `squarespace_refresh_token_expires_at` - When the refresh token expires

