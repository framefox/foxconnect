# Squarespace Product Sync Implementation

## Summary

Implemented complete product synchronization for Squarespace stores using the Products API v2, following the same architecture pattern as the existing Shopify product sync.

## Overview

The Squarespace product sync allows connected Squarespace stores to automatically import physical products and their variants into Framefox Connect for fulfillment management.

## Key Features

- **Physical Products Only**: Only PHYSICAL product types are synced (skips service, gift card, and download products)
- **Cursor-based Pagination**: Handles large product catalogs efficiently
- **Variant Support**: Syncs all product variants with pricing, SKU, and options
- **Auto-fulfillment**: Respects `fulfill_new_products` setting for new products/variants
- **Error Resilience**: Continues sync even if individual products fail
- **Platform-agnostic**: Integrates seamlessly with existing Store model methods

## Architecture

### Service Layer
**`SquarespaceProductSyncService`** (`app/services/squarespace_product_sync_service.rb`)
- Handles all API communication via `SquarespaceApiService`
- Maps Squarespace product/variant data to Framefox models
- Implements pagination logic
- Provides sync statistics

### Job Layer
**`SquarespaceProductSyncJob`** (`app/jobs/squarespace_product_sync_job.rb`)
- Queues sync operations via Sidekiq
- Validates store platform and token
- Updates last_sync_at timestamp
- Handles errors gracefully

### Integration Layer
**`SquarespaceIntegration`** concern updated to:
- Queue `SquarespaceProductSyncJob` via `sync_squarespace_products!`
- Integrates with Store model's `sync_products!` method

## Files Created

1. **`app/services/squarespace_product_sync_service.rb`**
   - 330+ lines of service logic
   - Handles product and variant synchronization
   - Implements field mappings and data transformations

2. **`app/jobs/squarespace_product_sync_job.rb`**
   - Background job for async product sync
   - Error handling and logging

## Files Modified

1. **`app/services/squarespace_api_service.rb`**
   - Updated `get_products` to use v2 endpoint (`/v2/commerce/products`)
   - Updated `get_product` to use v2 endpoint (`/v2/commerce/products/{id}`)

2. **`app/models/concerns/squarespace_integration.rb`**
   - Implemented `sync_squarespace_products!` to queue job
   - Added active store check

## Field Mappings

### Product Fields (Squarespace → Framefox)

| Squarespace Field | Framefox Field | Notes |
|-------------------|----------------|-------|
| `id` | `external_id` | Product identifier |
| `name` | `title` | Product name |
| `urlSlug` or `url` | `handle` | Uses urlSlug first, then extract from URL |
| `type` | `product_type`, `metadata.product_type` | Stored in both fields |
| `description` | `metadata.description` | HTML description stored in metadata |
| `tags` | `tags` | Array of tags |
| `isVisible` | `status` | Maps to "active" or "draft" |
| `createdOn` | `published_at` | ISO timestamp |
| `images[0].url` | `featured_image_url` | First image |
| `images` | `images` | Full image array |
| Full response | `metadata.squarespace_data` | Preserved for reference |

### Variant Fields (Squarespace → Framefox)

| Squarespace Field | Framefox Field | Notes |
|-------------------|----------------|-------|
| `id` | `external_variant_id` | Variant identifier |
| `sku` | `sku` | SKU for inventory tracking |
| `attributes.values` | `title` | Built from attribute values (e.g., "A2 / Walnut") |
| `pricing.basePrice.value` | `price` | Base price |
| `pricing.salePrice.value` | `price` | If onSale, base becomes compare_at |
| `pricing.onSale` | Logic for pricing | Determines price/compare_at mapping |
| `stock.quantity` | `metadata.stock_quantity` | Stored in metadata |
| `stock.unlimited` | `metadata.stock_unlimited` | Stored in metadata |
| N/A | `available_for_sale` | **Set to `true` by default** |
| `attributes` | `selected_options` | Variant options array |
| `shippable` | `requires_shipping` | Shipping requirement |
| `weight` | `weight`, `weight_unit` | Weight in pounds |
| Full response | `metadata.squarespace_data` | Preserved for reference |

## Product Type Filtering

**Only PHYSICAL products are synced:**

```ruby
unless product_data["type"] == "PHYSICAL"
  Rails.logger.info "Skipping non-physical product: #{product_data['name']} (type: #{product_data['type']})"
  products_skipped += 1
  next
end
```

Skipped product types:
- `SERVICE` - Services or experiences
- `GIFT_CARD` - Digital gift cards  
- `DOWNLOAD` - Digital downloads

## API Endpoints Used

- **List Products**: `GET /v2/commerce/products?cursor={cursor}`
  - Returns paginated product list with variants
  - Cursor-based pagination (50 per page)
  
- **Get Product**: `GET /v2/commerce/products/{id}`
  - Returns single product with all variants

## Usage

### Manual Sync (UI)

1. Navigate to a Squarespace store page in Connections
2. Click "Sync Products" button
3. Job is queued and runs in background
4. Refresh page to see synced products

### Programmatic Sync

```ruby
# Get store
store = Store.squarespace_stores.first

# Queue sync job
store.sync_products!
# or specifically:
store.sync_squarespace_products!

# Or run synchronously (for testing)
service = SquarespaceProductSyncService.new(store)
result = service.sync_all_products
# => { products_synced: 10, variants_synced: 45, products_skipped: 2 }
```

### Console Testing

```ruby
# Find your Squarespace store
store = Store.squarespace_stores.first

# Check API connection
store.squarespace_api_client.get_site_info

# Test product fetch
products_response = store.squarespace_api_client.get_products
puts "Found #{products_response['products'].count} products"

# Run sync
service = SquarespaceProductSyncService.new(store)
result = service.sync_all_products

puts "Synced #{result[:products_synced]} products"
puts "Synced #{result[:variants_synced]} variants"
puts "Skipped #{result[:products_skipped]} non-physical products"
```

## Error Handling

### Service Level
- Continues sync even if individual products fail
- Logs detailed error messages for debugging
- Returns partial success counts

### Job Level
- Validates store platform is `squarespace`
- Checks for access token presence
- Skips inactive stores
- Raises exceptions for complete failures (triggers retry)

### API Level
- Custom error classes: `SquarespaceApiError`, `SquarespaceAuthError`, `SquarespaceRateLimitError`
- Proper HTTP status code handling
- Detailed error messages in logs

## Performance Considerations

- **Pagination**: Fetches 50 products per page
- **Background Processing**: Runs async via Sidekiq
- **Batch Updates**: Single save per product/variant
- **Inactive Store Protection**: Prevents sync on inactive stores
- **Continued Processing**: Individual product failures don't stop sync

## Auto-Fulfillment

Respects store's `fulfill_new_products` setting:

```ruby
if is_new_product && store.fulfill_new_products
  product.fulfilment_active = true
end

if is_new_variant && store.fulfill_new_products
  variant.fulfilment_active = true
end
```

## Logging

Comprehensive logging at all levels:
- Product fetch operations
- Individual product/variant processing
- Skipped products (non-physical)
- Errors and failures
- Sync completion statistics

Example log output:
```
Fetching products from Squarespace for store: My Store
Fetched 50 products in this batch
Syncing product: Canvas Print (ID: 12345)
Skipping non-physical product: Consulting Session (type: SERVICE)
Processing 3 variants for product: Canvas Print
Sync completed: 10 products synced, 45 variants synced, 2 products skipped
```

## Testing Checklist

### Pre-requisites
- [ ] Squarespace store connected via OAuth
- [ ] Store has physical products with variants
- [ ] Store is marked as active

### Sync Testing
- [ ] Manual sync via UI works
- [ ] Products are created/updated correctly
- [ ] Variants are created with correct pricing
- [ ] Product handles are generated from URLs
- [ ] Featured images are set correctly
- [ ] Product status (active/draft) maps correctly
- [ ] Variant options are mapped correctly
- [ ] SKUs are preserved
- [ ] Pagination works for >50 products
- [ ] Non-physical products are skipped
- [ ] Re-sync updates existing products

### Auto-Fulfillment Testing
- [ ] `fulfill_new_products` enabled creates active products
- [ ] `fulfill_new_products` disabled creates inactive products
- [ ] Existing products retain fulfillment status

### Error Handling
- [ ] Invalid store platform is rejected
- [ ] Missing access token is handled
- [ ] Inactive store sync is skipped
- [ ] Individual product errors don't stop sync
- [ ] API errors are logged properly

## Differences from Shopify Sync

| Aspect | Shopify | Squarespace |
|--------|---------|-------------|
| API Type | GraphQL | REST/JSON |
| API Version | 2025-10 | v2 |
| Product Types | All | Physical only |
| Pagination | Cursor (edges/nodes) | Cursor (array) |
| IDs | GID format | Simple integers |
| Variant Images | Per-variant | Product-level only |
| Vendor | Supported | Not available |
| Weight Unit | Multiple | Pounds (assumed) |

## Future Enhancements

- Webhook integration for real-time product updates
- Inventory level synchronization
- Product image uploads to Squarespace
- Support for service/gift card products
- Automatic variant mapping suggestions
- Scheduled sync (daily/weekly)

## Troubleshooting

### Products not syncing
1. Check store is active
2. Verify access token is present
3. Check logs for API errors
4. Ensure products are PHYSICAL type

### Variants missing
1. Check product has variants in Squarespace
2. Verify variant data structure in logs
3. Check for position conflicts

### Price discrepancies
1. Verify `pricing.onSale` logic
2. Check currency conversion if needed
3. Review price field mapping in logs

## References

- [Squarespace Products API v2](https://developers.squarespace.com/commerce-apis/products-overview)
- [Retrieve All Products Endpoint](https://developers.squarespace.com/commerce-apis/retrieve-all-products)
- [Squarespace Authentication](https://developers.squarespace.com/commerce-apis/authentication-and-permissions)

## Implementation Date

November 2025

## Related Guides

- `SQUARESPACE_OAUTH_IMPLEMENTATION.md` - OAuth connection setup
- `SHOPIFY_CONFIG_SETUP.md` - Reference Shopify implementation

