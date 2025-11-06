# Squarespace Order Fulfillment Implementation Plan

## Status: ✅ IMPLEMENTATION COMPLETE

See `SQUARESPACE_FULFILLMENT_IMPLEMENTATION.md` for full implementation details.

## Overview

This document outlined the plan for implementing outbound fulfillment syncing to Squarespace when orders are fulfilled in FoxConnect. Unlike Shopify, Squarespace only supports marking entire orders as fulfilled, not individual line items. However, according to the [Squarespace Commerce API docs](https://developers.squarespace.com/commerce-apis/fulfill-order), multiple shipments can be added to an order even after it's marked as FULFILLED.

## Key Constraints

1. **Entire Order Fulfillment**: Squarespace can only mark entire orders as fulfilled, not individual line items like Shopify
2. **Multiple Shipments Supported**: Additional shipments can be added to an order at any time, even after status is FULFILLED
3. **Shipment Notifications**: Each fulfillment should send shipment/tracking information to Squarespace

## Recommended Approach

### Strategy: Send Fulfillment Data for Each Shipment

**Send a fulfillment/shipment notification to Squarespace each time we create a fulfillment in FoxConnect**, regardless of whether it's the first fulfillment or a subsequent one.

**Rationale:**

- Even though Squarespace marks the entire order as FULFILLED on first shipment, they support adding additional shipments
- This mirrors our Shopify behavior where we sync each fulfillment
- Customers will receive tracking information for each shipment
- Squarespace order page will show all shipments with their respective tracking info
- Maintains consistency in our system - every fulfillment gets synced to the platform

### Alternative Approach Considered (Not Recommended)

Only send fulfillment on the first item fulfilled:

- **Cons**: Subsequent shipments wouldn't sync to Squarespace
- **Cons**: Customers would only see tracking for first shipment
- **Cons**: No visibility into additional shipments in Squarespace admin
- **Cons**: Inconsistent with how we handle Shopify fulfillments

## Implementation Plan

### 1. Create `OutboundSquarespaceFulfillmentService`

Create a new service mirroring the pattern of `OutboundFulfillmentService` for Shopify.

**File**: `app/services/outbound_squarespace_fulfillment_service.rb`

**Responsibilities:**

- Accept a `Fulfillment` record
- Build Squarespace fulfillment payload from our fulfillment data
- Call `SquarespaceApiService#fulfill_order` with the payload
- Handle API errors and log results
- Record sync status in activity log

**Key Logic:**

```ruby
def sync_to_squarespace
  # Only sync Squarespace orders
  return unless store.platform == "squarespace"
  return unless order.external_id.present?
  return unless store.active?

  # Build fulfillment payload
  payload = build_fulfillment_payload

  # Send to Squarespace
  api_service = SquarespaceApiService.new(
    access_token: store.squarespace_token,
    store: store
  )

  response = api_service.fulfill_order(order.external_id, payload)

  # Log success
  log_success_activity(response)
  { success: true, response: response }
rescue => e
  # Log error
  log_error_activity(e.message)
  { success: false, error: e.message }
end
```

**Payload Structure** (based on Squarespace API docs):

```ruby
def build_fulfillment_payload
  {
    shouldSendNotification: true,  # Send tracking email to customer
    shipments: [
      {
        shipDate: fulfillment.fulfilled_at&.iso8601,
        carrierName: fulfillment.tracking_company,
        trackingNumber: fulfillment.tracking_number,
        trackingUrl: fulfillment.tracking_url,
        # Include line items that were fulfilled
        # Note: Squarespace doesn't require line items in payload (marks entire order)
        # but we can include them for clarity/future compatibility
      }.compact
    ]
  }
end
```

### 2. Update `InboundFulfillmentService`

Modify the existing `InboundFulfillmentService` to also sync to Squarespace after syncing to Shopify.

**File**: `app/services/inbound_fulfillment_service.rb`

**Changes:**

```ruby
def create_fulfillment
  ActiveRecord::Base.transaction do
    # ... existing code ...

    if fulfillment.save
      create_fulfillment_line_items(fulfillment)
      log_fulfillment_activity(fulfillment)
      update_order_state
      sync_to_platform(fulfillment)  # Changed from sync_to_shopify
      send_fulfillment_notification(fulfillment)
      fulfillment
    end
  end
end

private

def sync_to_platform(fulfillment)
  case fulfillment.order.store.platform
  when "shopify"
    sync_to_shopify(fulfillment)
  when "squarespace"
    sync_to_squarespace(fulfillment)
  end
end

def sync_to_shopify(fulfillment)
  # Existing Shopify sync logic
  outbound_service = OutboundFulfillmentService.new(fulfillment: fulfillment)
  outbound_service.sync_to_shopify
rescue StandardError => e
  Rails.logger.error "Outbound Shopify fulfillment sync failed: #{e.message}"
  # Don't fail the inbound fulfillment if outbound sync fails
end

def sync_to_squarespace(fulfillment)
  # New Squarespace sync logic
  outbound_service = OutboundSquarespaceFulfillmentService.new(fulfillment: fulfillment)
  outbound_service.sync_to_squarespace
rescue StandardError => e
  Rails.logger.error "Outbound Squarespace fulfillment sync failed: #{e.message}"
  # Don't fail the inbound fulfillment if outbound sync fails
end
```

### 3. Update `Fulfillment` Model (Optional)

Add Squarespace-specific fields if needed for tracking sync status.

**File**: `app/models/fulfillment.rb`

**Potential Changes:**

- Add `squarespace_fulfillment_id` field if Squarespace API returns fulfillment IDs
- Currently has `shopify_fulfillment_id` - may want to make this platform-agnostic

**Migration:**

```ruby
add_column :fulfillments, :squarespace_fulfillment_id, :string
add_index :fulfillments, :squarespace_fulfillment_id, unique: true
```

### 4. Update `OrderActivityService`

Add activity logging methods for Squarespace fulfillment sync events.

**File**: `app/services/order_activity_service.rb`

**New Methods:**

```ruby
def log_squarespace_fulfillment_synced(fulfillment:)
  log_activity(
    activity_type: "fulfillment_synced",
    title: "Fulfillment synced to Squarespace",
    description: "Shipment ##{fulfillment.id} synced with tracking: #{fulfillment.carrier_and_tracking}",
    metadata: {
      fulfillment_id: fulfillment.id,
      tracking_number: fulfillment.tracking_number,
      tracking_company: fulfillment.tracking_company,
      platform: "squarespace"
    }
  )
end

def log_squarespace_fulfillment_sync_failed(fulfillment:, error:)
  log_activity(
    activity_type: "fulfillment_sync_failed",
    title: "Squarespace fulfillment sync failed",
    description: "Failed to sync shipment ##{fulfillment.id}: #{error}",
    metadata: {
      fulfillment_id: fulfillment.id,
      error: error,
      platform: "squarespace"
    }
  )
end
```

### 5. Handle Squarespace API Response

Based on the Squarespace API documentation, the fulfill endpoint returns:

- Updated order object with fulfillment information
- May include fulfillment ID or shipment details

**Expected Response Handling:**

```ruby
# In OutboundSquarespaceFulfillmentService
def handle_response(response)
  # Response should be the updated order object
  # Extract any fulfillment identifiers if present
  if response["fulfillments"].present?
    # Store fulfillment ID if Squarespace provides one
    squarespace_fulfillment_id = response["fulfillments"].last["id"]
    fulfillment.update(squarespace_fulfillment_id: squarespace_fulfillment_id)
  end

  Rails.logger.info "Successfully synced fulfillment #{fulfillment.id} to Squarespace"
end
```

## Testing Strategy

### Unit Tests

1. **OutboundSquarespaceFulfillmentService**

   - Test payload construction with full tracking info
   - Test payload construction with partial tracking info (only number, only URL, etc.)
   - Test error handling (API failures, missing tokens, inactive stores)
   - Test that it only processes Squarespace orders
   - Test activity logging (success and failure)

2. **InboundFulfillmentService**
   - Test that Squarespace fulfillments call the new service
   - Test that Shopify fulfillments still work as before
   - Test error handling doesn't break fulfillment creation

### Integration Tests

1. **Full Fulfillment Flow**

   - Create Squarespace order
   - Create fulfillment with tracking info
   - Verify OutboundSquarespaceFulfillmentService is called
   - Verify API payload is correct
   - Verify activity is logged

2. **Multiple Fulfillments**

   - Create order with multiple items
   - Fulfill first item
   - Verify Squarespace API called
   - Fulfill second item
   - Verify Squarespace API called again (additional shipment)

3. **Partial Fulfillments**
   - Create order with 3 items
   - Fulfill 1 item - verify sync
   - Fulfill 1 more item - verify sync
   - Fulfill final item - verify sync and order marked as fulfilled

### Manual Testing Checklist

- [ ] Create test Squarespace order
- [ ] Fulfill first item in FoxConnect
- [ ] Verify Squarespace order shows FULFILLED status
- [ ] Verify first shipment appears in Squarespace
- [ ] Verify customer receives email with tracking
- [ ] Fulfill second item in FoxConnect
- [ ] Verify second shipment appears in Squarespace
- [ ] Verify customer receives second tracking email
- [ ] Test with missing tracking info (carrier only, number only, etc.)
- [ ] Test error handling (invalid token, API errors)
- [ ] Verify activity logs show sync events

## Error Handling

### Scenarios to Handle

1. **Missing/Expired Token**

   - Service should catch authentication errors
   - Log error in activity feed
   - Don't fail the fulfillment creation
   - Alert user that reconnection needed

2. **API Rate Limiting**

   - Catch rate limit errors
   - Log for debugging
   - Consider retry logic or background job

3. **Order Not Found**

   - Squarespace order may have been deleted
   - Log warning
   - Don't fail fulfillment

4. **Inactive Store**
   - Block sync attempts
   - Log warning
   - Return early with appropriate message

## Data Flow Diagram

```
FoxConnect Fulfillment Created
         ↓
InboundFulfillmentService.create_fulfillment
         ↓
sync_to_platform (detects Squarespace)
         ↓
OutboundSquarespaceFulfillmentService.sync_to_squarespace
         ↓
Build fulfillment payload
         ↓
SquarespaceApiService.fulfill_order
         ↓
POST /1.0/commerce/orders/{orderId}/fulfillments
         ↓
Squarespace marks order FULFILLED (if first shipment)
Squarespace adds shipment tracking
Squarespace sends customer notification (if shouldSendNotification: true)
         ↓
Response returned to OutboundSquarespaceFulfillmentService
         ↓
Log success/failure in OrderActivity
         ↓
Complete
```

## Migration Path

### Phase 1: Core Implementation

1. Create `OutboundSquarespaceFulfillmentService`
2. Add database migration for `squarespace_fulfillment_id`
3. Update `InboundFulfillmentService` to route to correct service
4. Add activity logging methods

### Phase 2: Testing

1. Write unit tests
2. Write integration tests
3. Manual testing with test Squarespace store

### Phase 3: Deployment

1. Deploy to staging
2. Test with real Squarespace test store
3. Monitor logs for errors
4. Deploy to production

### Phase 4: Monitoring

1. Monitor activity logs for sync failures
2. Watch for rate limiting issues
3. Collect feedback on customer notifications
4. Monitor for any edge cases

## Open Questions

1. **Fulfillment ID Storage**: Does Squarespace API return fulfillment IDs? Need to check API response.
2. **Line Items**: Should we include line item details in the fulfillment payload? (Not required by API but may be useful)
3. **Notification Control**: Should we always set `shouldSendNotification: true` or make it configurable?
4. **Status Mapping**: How do we handle Squarespace fulfillment status updates if they have webhooks?
5. **Retry Logic**: Should failed syncs be retried automatically via background job?

## Future Enhancements

1. **Background Jobs**: Move fulfillment sync to Sidekiq background jobs for better reliability
2. **Retry Mechanism**: Implement exponential backoff for failed syncs
3. **Webhook Support**: Listen for Squarespace fulfillment webhooks (if they exist)
4. **Bulk Fulfillment**: Support fulfilling multiple items in one Squarespace API call
5. **Cancellation Support**: Handle fulfillment cancellations in Squarespace

## Dependencies

- Existing `SquarespaceApiService` with `fulfill_order` method ✅ (already implemented)
- Existing `InboundFulfillmentService` ✅
- Existing `Fulfillment` model ✅
- Existing `OrderActivityService` ✅
- Squarespace OAuth connection with valid tokens ✅

## Success Criteria

- ✅ Each fulfillment created in FoxConnect syncs to Squarespace
- ✅ First fulfillment marks Squarespace order as FULFILLED
- ✅ Subsequent fulfillments add additional shipments
- ✅ Customers receive tracking notifications
- ✅ Activity logs show sync status (success/failure)
- ✅ Error handling prevents fulfillment creation from failing
- ✅ Works with partial fulfillments (multiple shipments)
- ✅ Tracking information (carrier, number, URL) syncs correctly

## Timeline Estimate

- **OutboundSquarespaceFulfillmentService**: 2-3 hours
- **InboundFulfillmentService updates**: 1 hour
- **Database migration**: 30 minutes
- **Activity logging**: 1 hour
- **Unit tests**: 2-3 hours
- **Integration tests**: 2-3 hours
- **Manual testing**: 2 hours
- **Documentation updates**: 1 hour

**Total: ~12-15 hours**

## Conclusion

This implementation will provide seamless fulfillment syncing from FoxConnect to Squarespace, ensuring:

1. Customers receive tracking information for all shipments
2. Squarespace orders show accurate fulfillment status
3. Multiple shipments are properly tracked
4. Consistent behavior with our Shopify fulfillment system

The recommended approach of sending fulfillment data for each shipment (rather than just the first) provides the best customer experience and maintains parity with Squarespace's multi-shipment capabilities.
