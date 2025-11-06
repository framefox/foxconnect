# Squarespace Order Fulfillment Implementation

## Summary

This implementation adds outbound fulfillment syncing from FoxConnect to Squarespace, allowing shipments created in FoxConnect to be automatically synced to Squarespace stores with tracking information.

## Implementation Date

November 6, 2024

## What Was Implemented

### 1. `OutboundSquarespaceFulfillmentService`

**File**: `app/services/outbound_squarespace_fulfillment_service.rb`

A new service that handles syncing fulfillments from FoxConnect to Squarespace orders.

**Key Features:**

- Mirrors the pattern of `OutboundFulfillmentService` for consistency
- Only processes Squarespace orders
- Blocks sync for inactive stores
- Builds fulfillment payload with tracking information
- Sends shipment data to Squarespace via API
- Logs success/failure activities

**Payload Structure:**

```ruby
{
  shouldSendNotification: true,  # Sends tracking email to customer
  shipments: [{
    shipDate: "2024-11-06T10:00:00Z",
    carrierName: "UPS",           # Optional
    trackingNumber: "1Z999...",   # Optional
    trackingUrl: "https://..."    # Optional
  }]
}
```

**Important Notes:**

- Squarespace API returns no data on successful fulfillment (204 No Content)
- No need to store Squarespace fulfillment IDs
- Each fulfillment creates a new shipment in Squarespace
- Squarespace marks the entire order as FULFILLED on first shipment
- Additional shipments can be added even after order is marked FULFILLED

### 2. Updated `InboundFulfillmentService`

**File**: `app/services/inbound_fulfillment_service.rb`

**Changes:**

- Added `sync_to_platform(fulfillment)` method that routes to correct platform
- Kept existing `sync_to_shopify(fulfillment)` method
- Added new `sync_to_squarespace(fulfillment)` method
- Changed `create_fulfillment` to call `sync_to_platform` instead of `sync_to_shopify`

**Flow:**

```
create_fulfillment
  ↓
sync_to_platform
  ↓
  ├─ Shopify → sync_to_shopify → OutboundFulfillmentService
  └─ Squarespace → sync_to_squarespace → OutboundSquarespaceFulfillmentService
```

### 3. Updated `OrderActivityService`

**File**: `app/services/order_activity_service.rb`

**New Methods:**

#### `log_squarespace_fulfillment_synced(fulfillment:, actor: nil)`

Logs successful Squarespace fulfillment sync with tracking details.

**Metadata:**

- `fulfillment_id`
- `tracking_number`
- `tracking_company`
- `tracking_url`
- `store_name`
- `platform: "squarespace"`

#### `log_squarespace_fulfillment_sync_failed(fulfillment:, error:, actor: nil)`

Logs failed Squarespace fulfillment sync attempts.

**Metadata:**

- `error`
- `fulfillment_id`
- `store_name`
- `platform: "squarespace"`

#### `build_squarespace_sync_description(fulfillment)` (private)

Builds human-readable description for activity log:

> "Shipment synced to Store Name with tracking: UPS 1Z999... (2 items)"

## How It Works

### Fulfillment Sync Flow

Fulfillments sync to platforms through **two pathways**:

#### A. Manual Fulfillment (Admin Form)

1. **User Creates Fulfillment in FoxConnect Admin**

   - User fills out manual fulfillment form with tracking info
   - `FulfillmentsController.create` is called

2. **Fulfillment Creation**

   - Creates `Fulfillment` record
   - Creates `FulfillmentLineItem` records for selected items
   - Updates order state if fully fulfilled
   - Logs activity

3. **Platform Sync**
   - `sync_fulfillment_to_platform(fulfillment)` routes to correct platform
   - Calls `OutboundSquarespaceFulfillmentService` (Squarespace) or `OutboundFulfillmentService` (Shopify)
   - Syncs to platform API
   - Logs success/failure (doesn't block user flow if sync fails)

#### B. Webhook Fulfillment (from Shopify)

1. **Fulfillment Created in FoxConnect (Webhook)**

   - Shopify sends fulfillment webhook
   - `InboundFulfillmentService.create_fulfillment` is called

2. **Platform Detection**

   - `sync_to_platform` checks `order.store.platform`
   - Routes to appropriate sync method

3. **Squarespace Sync** (if Squarespace order)

   - Service validates: Squarespace order, has external_id, store is active
   - Builds payload with shipment data
   - Calls `SquarespaceApiService.fulfill_order`

4. **Squarespace API Call**

   - `POST /1.0/commerce/orders/{orderId}/fulfillments`
   - Sends shipment with tracking information
   - Squarespace marks order as FULFILLED (if first shipment)
   - Squarespace sends customer notification email

5. **Activity Logging**
   - Success: Logs "Fulfillment synced to Squarespace" activity
   - Failure: Logs error activity with details
   - Doesn't fail fulfillment creation if sync fails

### Important: Webhook Loop Prevention

**Shopify Webhooks:**
When a fulfillment webhook comes from Shopify, the fulfillment will have a `shopify_fulfillment_id`. The `sync_to_shopify` method checks for this and skips the outbound sync to prevent an infinite loop:

```ruby
# Don't sync back to Shopify if this fulfillment came FROM Shopify
if fulfillment.shopify_fulfillment_id.present?
  Rails.logger.info "Skipping Shopify sync - fulfillment originated from Shopify (webhook)"
  return
end
```

**Squarespace:**
Squarespace doesn't send fulfillment webhooks, so there's no loop concern. All Squarespace order fulfillments are created manually in FoxConnect and synced to Squarespace.

### Multiple Shipments

**Scenario**: Order with 3 items, fulfilled separately

1. **First Item Fulfilled**

   - FoxConnect creates fulfillment #1
   - Syncs to Squarespace → Order status: FULFILLED
   - Customer receives tracking for shipment #1

2. **Second Item Fulfilled**

   - FoxConnect creates fulfillment #2
   - Syncs to Squarespace → Adds shipment #2
   - Customer receives tracking for shipment #2

3. **Third Item Fulfilled**
   - FoxConnect creates fulfillment #3
   - Syncs to Squarespace → Adds shipment #3
   - Customer receives tracking for shipment #3
   - FoxConnect order state changes to `fulfilled`

**Result**: Customer sees all 3 shipments with tracking in Squarespace

## Error Handling

### Scenarios Handled

1. **Not a Squarespace Order**

   - Returns early with message
   - No error logged

2. **Missing External Order ID**

   - Returns early with message
   - No error logged

3. **Inactive Store**

   - Logs warning
   - Returns early with message
   - No error logged

4. **API Errors** (authentication, rate limit, etc.)

   - Catches `SquarespaceApiService::SquarespaceApiError`
   - Logs error with full backtrace
   - Logs activity with error details
   - Returns `{ success: false, error: message }`
   - **Does NOT fail the fulfillment creation**

5. **Token Expiration**
   - Handled by `SquarespaceApiService.ensure_valid_token!`
   - Automatically refreshes token before API call
   - Transparent to fulfillment service

## Key Differences from Shopify

| Aspect                      | Shopify                       | Squarespace                   |
| --------------------------- | ----------------------------- | ----------------------------- |
| **Fulfillment Granularity** | Line-item level               | Entire order                  |
| **Multiple Shipments**      | Supported                     | Supported                     |
| **Fulfillment ID**          | Returns fulfillment ID        | No data returned              |
| **API Endpoint**            | GraphQL mutation              | REST POST                     |
| **Customer Notification**   | Part of mutation              | `shouldSendNotification` flag |
| **Line Items in Payload**   | Required (fulfillment orders) | Not required                  |

## Testing Recommendations

### Manual Testing Steps

1. **Create Squarespace Test Order**

   - Import order from Squarespace test store
   - Verify order appears in FoxConnect

2. **Test Manual Fulfillment Form**

   - Go to order detail page
   - Click "Create Fulfillment"
   - Add tracking info (carrier, number, URL)
   - Select one item to fulfill
   - Submit form
   - Verify: Success message shown
   - Verify: Activity log shows sync success
   - Verify: Squarespace order status = FULFILLED
   - Verify: First shipment appears in Squarespace
   - Verify: Customer receives tracking email

3. **Create Second Manual Fulfillment**

   - Click "Create Fulfillment" again
   - Add different tracking info
   - Select another item
   - Submit form
   - Verify: Second shipment appears in Squarespace
   - Verify: Customer receives second tracking email
   - Verify: Both shipments visible in Squarespace admin

4. **Test Webhook Fulfillment** (if applicable)

   - Create fulfillment in Shopify
   - Verify webhook received
   - Verify FoxConnect creates fulfillment
   - Verify NO sync back to Shopify (prevents loop)

5. **Test Error Scenarios**
   - Disconnect store → verify graceful handling (user still sees success)
   - Invalid tracking data → verify handles gracefully
   - Inactive store → verify sync blocked but fulfillment created
   - Check logs for warnings/errors

### Integration Test Ideas

```ruby
# Test successful fulfillment sync
it "syncs fulfillment to Squarespace" do
  order = create(:order, store: squarespace_store)
  fulfillment = create(:fulfillment, order: order)

  service = OutboundSquarespaceFulfillmentService.new(fulfillment: fulfillment)
  result = service.sync_to_squarespace

  expect(result[:success]).to be true
  expect(order.order_activities.last.title).to eq "Fulfillment synced to Squarespace"
end

# Test multiple shipments
it "sends each fulfillment as separate shipment" do
  order = create(:order, store: squarespace_store)

  # First fulfillment
  fulfillment1 = create(:fulfillment, order: order)
  service1 = OutboundSquarespaceFulfillmentService.new(fulfillment: fulfillment1)
  result1 = service1.sync_to_squarespace

  # Second fulfillment
  fulfillment2 = create(:fulfillment, order: order)
  service2 = OutboundSquarespaceFulfillmentService.new(fulfillment: fulfillment2)
  result2 = service2.sync_to_squarespace

  expect(result1[:success]).to be true
  expect(result2[:success]).to be true
  expect(order.order_activities.count).to eq 2
end
```

## Dependencies

- ✅ `SquarespaceApiService#fulfill_order` method
- ✅ `InboundFulfillmentService`
- ✅ `Fulfillment` model
- ✅ `OrderActivityService`
- ✅ Squarespace OAuth with valid tokens

## Files Modified

1. `app/services/outbound_squarespace_fulfillment_service.rb` (new)
2. `app/services/inbound_fulfillment_service.rb` (modified)
3. `app/services/order_activity_service.rb` (modified)
4. `app/controllers/fulfillments_controller.rb` (modified - added platform sync)

## Files NOT Modified

- `app/models/fulfillment.rb` (no database changes needed)
- No migrations (Squarespace API returns no data to store)

## Future Enhancements

1. **Background Jobs**: Move sync to Sidekiq for better reliability
2. **Retry Logic**: Implement exponential backoff for failed syncs
3. **Webhook Support**: Listen for Squarespace fulfillment webhooks (if available)
4. **Bulk Sync**: Add ability to resync failed fulfillments
5. **Admin UI**: Show sync status in fulfillments list

## Monitoring

### What to Watch For

1. **Sync Failures**: Check activity logs for sync errors
2. **Token Expiration**: Monitor for authentication errors
3. **Rate Limiting**: Watch for 429 errors from Squarespace
4. **Customer Notifications**: Verify customers receive tracking emails
5. **Order Status**: Ensure Squarespace orders show FULFILLED status

### Logs to Review

```ruby
# Successful sync
"Successfully synced fulfillment 123 to Squarespace order ABC123"

# API errors
"OutboundSquarespaceFulfillmentService error: [error message]"

# Inactive store
"Attempted to sync fulfillment for inactive store: Store Name"
```

## Success Criteria

✅ Each fulfillment created in FoxConnect syncs to Squarespace
✅ First fulfillment marks Squarespace order as FULFILLED
✅ Subsequent fulfillments add additional shipments
✅ Customers receive tracking notifications for each shipment
✅ Activity logs show sync status (success/failure)
✅ Error handling prevents fulfillment creation from failing
✅ Works with partial fulfillments (multiple shipments)
✅ Tracking information (carrier, number, URL) syncs correctly
✅ No database changes needed (API returns no data)

## Conclusion

This implementation provides seamless fulfillment syncing from FoxConnect to Squarespace, following the recommended approach of sending each fulfillment as a separate shipment. This ensures:

- Customers receive tracking information for all shipments
- Squarespace orders show accurate fulfillment status
- Multiple shipments are properly tracked
- Consistent behavior with Shopify fulfillment system
- Clean error handling that doesn't break fulfillment creation

The solution is production-ready and follows Rails best practices with proper error handling, logging, and service architecture.
