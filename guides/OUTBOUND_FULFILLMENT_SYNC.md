# Outbound Fulfillment Sync to Shopify

## Overview

The outbound fulfillment sync pushes Framefox-created fulfillments back to the original Shopify store, ensuring merchants see tracking information in their Shopify admin.

## Architecture

### Two-Way Fulfillment Flow

```
Shopify Store → [Inbound] → FoxConnect → [Outbound] → Shopify Store
```

**Inbound (InboundFulfillmentService)**:

- Receives Shopify fulfillment webhooks
- Creates local fulfillment records
- Tracks items fulfilled by external parties

**Outbound (OutboundFulfillmentService)**:

- Pushes Framefox fulfillments to Shopify
- Enables merchants to see tracking in their admin
- Closes the fulfillment loop

## Services

### InboundFulfillmentService

**Purpose**: Process Shopify fulfillment webhooks (from external fulfillments)

**File**: `app/services/inbound_fulfillment_service.rb`

**Responsibilities**:

- Parse Shopify webhook data
- Create local fulfillment records
- Match line items by `shopify_remote_line_item_id`
- Update order state
- Trigger outbound sync (for Shopify orders)

### OutboundFulfillmentService

**Purpose**: Sync Framefox fulfillments back to Shopify

**File**: `app/services/outbound_fulfillment_service.rb`

**Responsibilities**:

- Query Shopify order for fulfillment orders
- Match local line items to Shopify fulfillment order line items
- Create fulfillment in Shopify with tracking info
- Log success/failure activities

## How It Works

### Full Flow

1. **Order created in Shopify** → Imported to FoxConnect
2. **Order submitted** → Sent to Framefox production system
3. **Items produced and shipped** → Fulfillment created in FoxConnect
4. **OutboundFulfillmentService triggered** → Syncs to original Shopify store
5. **Merchant sees tracking** → In their Shopify admin

### Outbound Sync Process

```ruby
OutboundFulfillmentService.new(fulfillment: fulfillment).sync_to_shopify
```

**Step 1**: Query Shopify for fulfillment orders

```graphql
query {
  order(id: "gid://shopify/Order/123") {
    fulfillmentOrders(query: "status:open OR status:in_progress") {
      id
      lineItems {
        id
        lineItem {
          id
        }
        remainingQuantity
      }
    }
  }
}
```

**Step 2**: Match local line items to Shopify structure

- Maps `fulfillment.fulfillment_line_items` → `FulfillmentOrderLineItem` IDs
- Uses `shopify_remote_line_item_id` to match
- Validates remaining quantity

**Step 3**: Create fulfillment in Shopify

```graphql
mutation {
  fulfillmentCreate(fulfillment: {
    notifyCustomer: true
    trackingInfo: {
      company: "Carrier Name"
      number: "TRACK123"
      url: "https://track.example.com/..."
    }
    lineItemsByFulfillmentOrder: [...]
  }) {
    fulfillment { id status }
    userErrors { field message }
  }
}
```

**Step 4**: Log activity

- Success → "Fulfillment Synced to Shopify"
- Failure → "Fulfillment Sync to Shopify Failed" with error

## When Does Outbound Sync Occur?

### Automatic Triggers

Outbound sync is **automatically** triggered when:

1. **Inbound webhook creates fulfillment** (InboundFulfillmentService)
2. Fulfillment is saved successfully
3. Order belongs to a Shopify store

### Important Notes

- ✓ Sync happens **outside transaction** - won't block inbound fulfillment
- ✓ Errors are logged but don't fail the inbound process
- ✓ Only runs for Shopify platform stores
- ✓ Skipped if order doesn't have `shopify_remote_order_id`

## Error Handling

### Robust Error Recovery

The outbound sync is designed to fail gracefully:

```ruby
def sync_to_shopify(fulfillment)
  return unless fulfillment.order.store.platform == "shopify"

  outbound_service = OutboundFulfillmentService.new(fulfillment: fulfillment)
  outbound_service.sync_to_shopify
rescue StandardError => e
  Rails.logger.error "Outbound fulfillment sync failed: #{e.message}"
  # Don't fail the inbound fulfillment
end
```

**Error Scenarios Handled**:

- Store not Shopify → Silently skip
- Missing Shopify order ID → Return error, log activity
- Shopify API errors → Log activity with error details
- Network failures → Caught and logged
- GraphQL user errors → Parsed and logged

### Activity Logging

**Success Activity**:

- Type: `fulfillment_sync`
- Title: "Fulfillment Synced to Shopify"
- Description: "Fulfillment synced to [Store Name] with tracking [Number] (X items)"
- Metadata: shopify_fulfillment_id, tracking_number, fulfillment_id

**Error Activity**:

- Type: `fulfillment_sync_error`
- Title: "Fulfillment Sync to Shopify Failed"
- Description: Error message
- Metadata: error, fulfillment_id, store_name

## GraphQL API Details

### Required Scopes

Already configured in `config/initializers/shopify_app.rb`:

- ✓ `read_orders` - Query fulfillment orders
- ✓ `write_fulfillments` - Create fulfillments
- ✓ `read_fulfillments` - Read fulfillment orders

### API Version

Using: `2025-01` (configured in shopify_app initializer)

### Shopify Client Setup

```ruby
def shopify_client
  ShopifyAPI::Clients::Graphql::Admin.new(
    session: shopify_session
  )
end

def shopify_session
  ShopifyAPI::Auth::Session.new(
    shop: store.shopify_domain,
    access_token: store.shopify_token
  )
end
```

## Line Item Matching

### How Matching Works

1. **Local side**: `fulfillment.fulfillment_line_items` each have an `order_item`
2. **Order item** has: `shopify_remote_line_item_id` (set during production sync)
3. **Shopify side**: Query returns `FulfillmentOrderLineItem` with nested `lineItem.id`
4. **Match**: When `lineItem.id` == `"gid://shopify/LineItem/#{shopify_remote_line_item_id}"`

### Validation

- Checks `remainingQuantity` before adding to payload
- Skips items with insufficient remaining quantity
- Logs warnings for unmatched items
- Only includes matched items in Shopify fulfillment

## Testing

### Manual Test (Console)

```ruby
# Find a fulfillment
fulfillment = Fulfillment.last

# Check prerequisites
puts "Order ID: #{fulfillment.order.id}"
puts "Store: #{fulfillment.order.store.name}"
puts "Platform: #{fulfillment.order.store.platform}"
puts "Shopify Order ID: #{fulfillment.order.shopify_remote_order_id}"
puts "Items: #{fulfillment.item_count}"

# Run outbound sync
service = OutboundFulfillmentService.new(fulfillment: fulfillment)
result = service.sync_to_shopify

# Check result
if result[:success]
  puts "✓ Success! Shopify Fulfillment: #{result[:shopify_fulfillment_id]}"
else
  puts "✗ Failed: #{result[:error]}"
end

# Check activity log
fulfillment.order.recent_activities(5).each do |activity|
  puts "#{activity.title}: #{activity.description}"
end
```

### Automated Test (Rake Task)

```bash
# This will create a local fulfillment and trigger outbound sync
rails fulfillments:create_test[ORDER_ID]

# Check the order activity log
rails fulfillments:list[ORDER_ID]
```

Then verify in Shopify admin:

1. Go to Orders → Select the order
2. Should see fulfillment with tracking info
3. Check timeline for fulfillment event

## Troubleshooting

### Sync Not Happening

**Check**:

1. Is store platform "shopify"?

   ```ruby
   order.store.platform # Should be "shopify"
   ```

2. Does order have Shopify remote ID?

   ```ruby
   order.shopify_remote_order_id # Should not be nil
   ```

3. Check Rails logs:
   ```bash
   tail -f log/development.log | grep -i outbound
   ```

### "No fulfillment orders found"

**Cause**: Order doesn't have open/in_progress fulfillment orders in Shopify

**Check in Shopify**:

- Order might already be fully fulfilled
- Fulfillment orders might be cancelled

**Solution**: Query the order in Shopify admin to see fulfillment status

### "No matching line items found"

**Cause**: Local order items don't have `shopify_remote_line_item_id` set

**Check**:

```ruby
order.order_items.pluck(:id, :shopify_remote_line_item_id)
```

**Solution**: Ensure `OrderProductionService` sets this field when syncing to Shopify

### GraphQL Errors

**Check activity log**:

```ruby
order.order_activities.where(activity_type: 'fulfillment_sync_error').last.metadata
```

**Common errors**:

- "Invalid line item ID" → Line item doesn't exist in Shopify
- "Fulfillment order not found" → Order state changed in Shopify
- "Unauthorized" → Check Shopify token and scopes

## Activity Log Examples

### Success

```
Title: Fulfillment Synced to Shopify
Description: Fulfillment synced to Customer Store with tracking NZ0079421039261693147 (2 items)
Metadata:
  - shopify_fulfillment_id: gid://shopify/Fulfillment/123456
  - tracking_number: NZ0079421039261693147
  - fulfillment_id: 42
  - store_name: Customer Store
```

### Failure

```
Title: Fulfillment Sync to Shopify Failed
Description: Failed to sync fulfillment to Customer Store: lineItemsByFulfillmentOrder: Invalid fulfillment order line item ID
Metadata:
  - error: lineItemsByFulfillmentOrder: Invalid fulfillment order line item ID
  - fulfillment_id: 42
  - store_name: Customer Store
```

## Configuration

### Access Scopes

Already configured in `/config/initializers/shopify_app.rb`:

```ruby
config.scope = "read_orders,write_orders,read_fulfillments,write_fulfillments"
```

### API Version

Currently using: `2025-01`

To update, change in `config/initializers/shopify_app.rb`:

```ruby
config.api_version = "2025-01"
```

## Future Enhancements

### Potential Improvements

1. **Background Job Processing**

   - Move outbound sync to Sidekiq/ActiveJob
   - Retry failed syncs automatically
   - Better error recovery

2. **Fulfillment Batching**

   - Combine multiple local fulfillments into one Shopify fulfillment
   - Reduce API calls

3. **Bi-directional Sync**

   - Handle fulfillment updates from Shopify
   - Keep tracking info in sync

4. **Manual Retry**

   - UI button to retry failed syncs
   - Bulk retry for multiple failed syncs

5. **Status Monitoring**
   - Dashboard showing sync success rate
   - Alert on repeated failures

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────┐
│  Shopify Store (Original)                               │
│  - Order created                                        │
│  - External fulfillment (warehouse/3PL)                 │
└────────────┬────────────────────────────────────────────┘
             │
             │ Webhook: fulfillments/create
             ▼
┌─────────────────────────────────────────────────────────┐
│  FoxConnect - InboundFulfillmentService                 │
│  - Receive webhook                                      │
│  - Create local fulfillment                             │
│  - Track items fulfilled                                │
└────────────┬────────────────────────────────────────────┘
             │
             │ Trigger sync
             ▼
┌─────────────────────────────────────────────────────────┐
│  FoxConnect - OutboundFulfillmentService                │
│  - Query Shopify fulfillment orders                     │
│  - Match line items                                     │
│  - Create fulfillment with tracking                     │
└────────────┬────────────────────────────────────────────┘
             │
             │ GraphQL: fulfillmentCreate
             ▼
┌─────────────────────────────────────────────────────────┐
│  Shopify Store (Original)                               │
│  - Fulfillment appears in admin                         │
│  - Customer sees tracking                               │
│  - Order marked as fulfilled                            │
└─────────────────────────────────────────────────────────┘
```

## Files Modified/Created

### Created

- `app/services/outbound_fulfillment_service.rb` - New service for syncing to Shopify

### Renamed

- `app/services/fulfillment_service.rb` → `app/services/inbound_fulfillment_service.rb`

### Modified

- `app/services/inbound_fulfillment_service.rb` - Added `sync_to_shopify` method
- `app/controllers/webhooks/fulfillments_controller.rb` - Updated to use InboundFulfillmentService
- `lib/tasks/fulfillments.rake` - Updated service references

## Quick Reference

### Create and Sync Fulfillment

```ruby
# Create fulfillment (automatically syncs to Shopify)
service = InboundFulfillmentService.new(order: order, fulfillment_data: data)
fulfillment = service.create_fulfillment

# Manual sync (if needed)
outbound = OutboundFulfillmentService.new(fulfillment: fulfillment)
result = outbound.sync_to_shopify
```

### Check Sync Status

```ruby
# View recent sync activities
order.order_activities
  .where(activity_type: ['fulfillment_sync', 'fulfillment_sync_error'])
  .recent
  .each do |activity|
    puts "#{activity.title}: #{activity.description}"
  end
```

### Verify in Shopify

1. Log into Shopify admin for the store
2. Go to Orders → Find the order
3. Check "Fulfillment" section
4. Should see:
   - Fulfillment status
   - Tracking number (clickable)
   - Items fulfilled
   - Shipment timeline

## Success! 🎉

The outbound fulfillment sync is now fully integrated. When Framefox fulfills an order, the tracking information automatically appears in the merchant's Shopify admin.
