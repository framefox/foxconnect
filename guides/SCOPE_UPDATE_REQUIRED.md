# Shopify App Scope Update Required

## New Scopes Added

To enable outbound fulfillment sync, the following scopes were added:

- `read_merchant_managed_fulfillment_orders` - Read fulfillment orders
- `write_merchant_managed_fulfillment_orders` - Create fulfillments

## Why These Scopes?

The original `read_fulfillments` and `write_fulfillments` scopes are **legacy scopes** that don't grant access to the modern fulfillment orders API.

To use the `fulfillmentCreate` GraphQL mutation and query fulfillment orders, you need the `*_merchant_managed_fulfillment_orders` scopes.

## How to Apply New Scopes

### For Existing Store Installations

Stores that already have the app installed need to re-authenticate to grant the new scopes:

#### Option 1: Reinstall the App

1. Uninstall the app from the Shopify store
2. Reinstall via OAuth flow
3. Accept the new permission requests

#### Option 2: Request Scope Update

1. Go to: `https://[STORE].myshopify.com/admin/oauth/authorize?client_id=[YOUR_API_KEY]&scope=[NEW_SCOPES]&redirect_uri=[YOUR_CALLBACK_URL]`
2. Store owner approves new scopes
3. App receives updated access token

### For New Installations

New installations will automatically request the updated scopes during OAuth.

## Updated Scope List

**Full scope configuration** (in `config/initializers/shopify_app.rb`):

```
read_customers
write_customers
write_products
read_inventory
write_inventory
read_orders
write_orders
read_fulfillments
write_fulfillments
read_merchant_managed_fulfillment_orders  ← NEW
write_merchant_managed_fulfillment_orders ← NEW
read_locations
write_draft_orders
```

## Testing After Scope Update

Once scopes are updated, test the outbound sync:

```bash
rails runner "
  fulfillment = Fulfillment.find(FULFILLMENT_ID)
  service = OutboundFulfillmentService.new(fulfillment: fulfillment)
  result = service.sync_to_shopify
  puts result[:success] ? '✓ Success!' : '✗ Error: ' + result[:error]
"
```

## Verification

Check if scopes are active:

```ruby
# In Rails console
store = Store.first
session = ShopifyAPI::Auth::Session.new(
  shop: store.shopify_domain,
  access_token: store.shopify_token
)
client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

# Try querying fulfillment orders
query = "query { shop { name } }"
response = client.query(query: query)
puts response.body
```

If you get "Access denied for fulfillmentOrders field", the scopes haven't been updated yet.

## Impact

**Without new scopes**:

- ✗ Cannot query fulfillment orders
- ✗ Cannot create fulfillments in Shopify
- ✗ Outbound sync will fail with "Access denied"

**With new scopes**:

- ✓ Can query fulfillment orders
- ✓ Can create fulfillments in Shopify
- ✓ Outbound sync works correctly
- ✓ Merchants see tracking in their admin

## Next Steps

1. Restart Rails server to load new scope configuration
2. Re-authenticate stores with updated scopes
3. Test outbound sync
4. Verify fulfillments appear in Shopify admin
