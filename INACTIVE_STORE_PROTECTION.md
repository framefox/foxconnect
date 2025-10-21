# Inactive Store API Protection

## Overview

All Shopify API calls are now blocked when a store's `active` flag is set to `false`. This prevents API calls to stores that have uninstalled the app or should otherwise not be accessed.

## Protection Points

### 1. Core Session Creation (`ShopifyIntegration#shopify_session`)

**Location**: `app/models/concerns/shopify_integration.rb`

```ruby
def shopify_session
  return unless shopify? && shopify_token.present?

  # Block API calls to inactive stores
  unless active?
    Rails.logger.warn "Attempted Shopify API call to inactive store: #{name} (#{shopify_domain})"
    raise InactiveStoreError, "Cannot make API calls to inactive store: #{name}"
  end

  ShopifyAPI::Auth::Session.new(...)
end
```

**Impact**: All services using `store.shopify_session` are automatically protected.

### 2. Integration Methods Protected

All Shopify integration methods now check for `active?`:

- `sync_shopify_products!` - Returns early if inactive
- `sync_variant_image` - Returns early if inactive
- `batch_sync_variant_images` - Returns early if inactive
- `update_name_from_shopify!` - Returns early if inactive

### 3. Services Protected

#### ImportOrderService

**Location**: `app/services/import_order_service.rb`

- `call()` - Checks active before importing orders
- `resync_order()` - Checks active before resyncing orders

#### ShopifyProductSyncService

**Location**: `app/services/shopify_product_sync_service.rb`

- `initialize()` - Raises `InactiveStoreError` if store is inactive
- Prevents any product sync operations

#### OutboundFulfillmentService

**Location**: `app/services/outbound_fulfillment_service.rb`

- `sync_to_shopify()` - Returns error if store is inactive
- Prevents fulfillment creation in Shopify

#### ShopifyVariantImageSyncService

**Location**: `app/services/shopify_variant_image_sync_service.rb`

- Uses `store.shopify_session` - automatically protected

### 4. Jobs Protected

#### ShopifyProductSyncJob

**Location**: `app/jobs/shopify_product_sync_job.rb`

- Checks `store.active?` at start of job
- Gracefully handles `InactiveStoreError`
- Logs warning instead of raising error

#### UpdateShopifyStoreNameJob

**Location**: `app/jobs/update_shopify_store_name_job.rb`

- Protected via `update_name_from_shopify!` method

## Custom Error Class

```ruby
class ShopifyIntegration::InactiveStoreError < StandardError; end
```

This error is raised when attempting to make API calls to inactive stores. It can be caught and handled gracefully in jobs and services.

## Webhook Flow

When a merchant uninstalls the app:

1. **app/uninstalled webhook fires** (immediate)

   ```ruby
   @store.update(
     active: false,
     shopify_token: nil
   )
   ```

2. **All subsequent API calls are blocked**

   - Session creation fails with `InactiveStoreError`
   - Integration methods return early
   - Services raise errors or return failure messages
   - Jobs skip processing

3. **shop/redact webhook fires** (~48 hours later)
   - Admin receives email notification
   - Store data can be deleted manually

## Testing

To test the protection:

```ruby
# In rails console
store = Store.first
store.update(active: false)

# This will raise InactiveStoreError
store.shopify_session

# This will return nil
ImportOrderService.new(store: store, order_id: 123).call

# This will return early
store.sync_shopify_products!
```

## Benefits

✅ **Security**: Prevents unauthorized API calls to uninstalled apps  
✅ **Error Prevention**: Stops API calls that would fail anyway  
✅ **Resource Efficiency**: Doesn't waste API calls on inactive stores  
✅ **Clear Logging**: All blocked attempts are logged with warnings  
✅ **Graceful Degradation**: Returns nil or error messages instead of crashing
