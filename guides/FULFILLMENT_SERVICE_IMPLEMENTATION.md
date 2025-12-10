# Shopify Fulfillment Service Implementation

**Date**: December 10, 2025  
**Status**: Implemented

## Overview

This implementation registers Framefox Connect as a **Fulfillment Service** in Shopify, enabling merchants to see "Request fulfillment" instead of "Mark as fulfilled" in their Shopify Admin.

## How It Works

### Two Order Import Paths (Both Coexist)

| Trigger | How it Works |
|---------|--------------|
| `orders/create` webhook | Order placed → Webhook fires → App imports automatically (existing flow) |
| "Request fulfillment" button | Merchant clicks → Shopify notifies callback URL → App accepts request |

Both paths work together - the webhook continues importing orders automatically, while the fulfillment service integration adds merchant control.

### Flow Diagram

```
Store Connects via OAuth
        ↓
RegisterFulfillmentServiceJob runs
        ↓
fulfillmentServiceCreate mutation creates "Framefox Connect" location
        ↓
Store gets fulfillment_service_id and location_id saved
        ↓
User enables fulfillment for a product variant in FoxConnect
        ↓
InventoryActivationService moves inventory to Framefox location
        ↓
Orders for that product show "Request fulfillment" in Shopify Admin
```

## Key Components

### 1. Database Changes

New columns on `stores` table:
- `shopify_fulfillment_service_id` (string) - GID of our fulfillment service
- `shopify_fulfillment_location_id` (string) - GID of our fulfillment location

### 2. Services

| Service | Purpose |
|---------|---------|
| `FulfillmentServiceRegistrationService` | Registers app as fulfillment service on merchant store |
| `FulfillmentRequestHandlerService` | Handles accept/reject of fulfillment and cancellation requests |
| `InventoryActivationService` | Moves product inventory to/from our fulfillment location |

### 3. Jobs

| Job | Purpose |
|-----|---------|
| `RegisterFulfillmentServiceJob` | Runs after OAuth to register fulfillment service |

### 4. Controllers

| Controller | Endpoint | Purpose |
|------------|----------|---------|
| `Webhooks::FulfillmentOrderNotificationsController` | `POST /webhooks/fulfillment_order_notification` | Handles callback from Shopify when merchant clicks "Request fulfillment" |

### 5. Scope Updates

Added scopes:
- `write_fulfillments` - Create fulfillment service
- `read_assigned_fulfillment_orders` - Query fulfillment orders assigned to us
- `write_assigned_fulfillment_orders` - Accept/reject fulfillment requests
- `write_inventory` - Move products to our location
- `read_inventory` - Query inventory levels

## Print-on-Demand Configuration

Since Framefox is print-on-demand with infinite stock:

- Fulfillment service created with `inventoryManagement: false`
- No `/fetch_stock` endpoint needed
- Inventory activated with quantity `999999` (effectively infinite)

## Inventory Sync Logic

When fulfillment is **ENABLED** in FoxConnect:
```ruby
InventoryActivationService.new(product_variant).activate_at_fulfillment_location!
# → Moves inventory to Framefox location
# → Product orders route to our fulfillment service
# → Merchant sees "Request fulfillment"
```

When fulfillment is **DISABLED** in FoxConnect:
```ruby
InventoryActivationService.new(product_variant).deactivate_from_fulfillment_location!
# → Moves inventory back to merchant's default location
# → Product orders handled by merchant
# → Merchant sees "Mark as fulfilled"
```

## Handling Fulfillment Requests

When a fulfillment request callback is received:

1. Parse the `kind` field (`FULFILLMENT_REQUEST` or `CANCELLATION_REQUEST`)
2. For fulfillment requests: **Auto-accept** immediately (we're always ready)
3. For cancellation requests:
   - If order not in production: **Accept** cancellation
   - If order in production: **Reject** with message

## Files Created/Modified

### New Files
- `db/migrate/20251210100000_add_fulfillment_service_to_stores.rb`
- `app/services/fulfillment_service_registration_service.rb`
- `app/services/fulfillment_request_handler_service.rb`
- `app/services/inventory_activation_service.rb`
- `app/jobs/register_fulfillment_service_job.rb`
- `app/controllers/webhooks/fulfillment_order_notifications_controller.rb`

### Modified Files
- `shopify.app.toml` - Added scopes and webhook subscriptions
- `config/initializers/shopify_app.rb` - Added scopes
- `config/routes.rb` - Added callback route
- `app/models/store.rb` - Added job trigger after OAuth
- `app/services/shopify_product_sync_service.rb` - Added `inventoryItem.id` to queries
- `app/controllers/connections/stores/product_variants_controller.rb` - Added inventory sync on toggle

## Important Notes

1. **Existing stores**: Need to reconnect to get the fulfillment service registered. Alternatively, create a rake task to register for existing stores.

2. **Existing products with fulfillment enabled**: Their inventory needs to be moved to the fulfillment location. This happens automatically when the fulfillment toggle is changed, but existing products will need their toggle cycled (off then on) or a migration script run.

3. **Webhook HMAC verification**: The fulfillment_order_notification callback uses the same HMAC verification as other Shopify webhooks.

## Testing

1. Connect a new Shopify store
2. Check that `shopify_fulfillment_service_id` and `shopify_fulfillment_location_id` are populated
3. Enable fulfillment for a product variant
4. Create an order with that product
5. In Shopify Admin, verify "Request fulfillment" button appears
6. Click "Request fulfillment" and verify callback is received
7. Check that fulfillment request is auto-accepted

## References

- [Build for fulfillment services](https://shopify.dev/docs/apps/build/orders-fulfillment/fulfillment-service-apps/build-for-fulfillment-services)
- [fulfillmentServiceCreate mutation](https://shopify.dev/docs/api/admin-graphql/latest/mutations/fulfillmentServiceCreate)
- [fulfillmentOrderSubmitFulfillmentRequest mutation](https://shopify.dev/docs/api/admin-graphql/latest/mutations/fulfillmentOrderSubmitFulfillmentRequest)

