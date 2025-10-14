# Shopify Fulfillment System Implementation

## Summary

This implementation adds Shopify-style fulfillment tracking to FoxConnect, allowing orders to be tracked through multiple fulfillments with complete shipping and tracking information.

## What Was Implemented

### 1. Database Schema

**Fulfillments Table** (`fulfillments`)

- Tracks individual fulfillment events from Shopify
- Stores tracking information (carrier, number, URL)
- Links to the parent order
- Supports multiple fulfillments per order

**Fulfillment Line Items Table** (`fulfillment_line_items`)

- Junction table connecting fulfillments to specific order items
- Tracks quantity fulfilled (supports partial fulfillments)
- Prevents duplicate fulfillment of same items

### 2. Models

**`Fulfillment`**

- Belongs to order
- Has many order items through fulfillment_line_items
- Includes helper methods for tracking info display
- Scopes for successful/recent fulfillments

**`FulfillmentLineItem`**

- Validates quantity doesn't exceed order item quantity
- Links fulfillment to specific order items

**Updated `Order`**

- New AASM state: `fulfilled`
- New event: `fulfill` (auto-transitions when fully fulfilled)
- Helper methods: `fulfillment_status`, `fulfilled_items_count`, `unfulfilled_items_count`, `partially_fulfilled?`, `fully_fulfilled?`

**Updated `OrderItem`**

- New methods: `fulfilled_quantity`, `unfulfilled_quantity`, `fully_fulfilled?`, `partially_fulfilled?`
- Tracks fulfillment status at item level

### 3. Services

**`FulfillmentService`**

- Processes Shopify fulfillment webhook data
- Creates fulfillment records with line items
- Matches Shopify line items to local order items via `shopify_remote_line_item_id`
- Handles tracking URL building
- Logs fulfillment activities
- Auto-updates order state when fully fulfilled

### 4. Webhook Handler

**`Webhooks::FulfillmentsController`**

- Handles `POST /webhooks/fulfillments/create`
- Handles `POST /webhooks/fulfillments/update`
- Verifies webhooks (TODO: implement HMAC verification)
- Processes fulfillment data through `FulfillmentService`

### 5. UI Updates

**Orders Show Page** (`app/views/orders/show.html.erb`)

**Conditional Grouping Behavior:**

- **For `draft` and `cancelled` orders**: Shows original grouping by fulfillment-enabled status
  - "To be fulfilled by Framefox" section (fulfillable items)
  - "Not Fulfilled by Framefox" section (non-fulfillable items)
- **For `in_production` and `fulfilled` orders**: Shows fulfillment-based grouping
  - **Unfulfilled section** appears first (yellow badge)
  - **Fulfilled sections** appear below (green badge, one per fulfillment)

**Each fulfillment section shows:**

- Item count in badge
- Fulfillment location badge
- Fulfillment ID in top-right
- Date fulfilled
- Carrier and tracking information (with clickable link to tracking URL)
- List of fulfilled items with quantities

**Status Badges**

- Updated `order_state_badge` helper to show "Fulfilled" state with green badge and check icon

## Shopify Webhook Configuration

### Required Webhooks

Subscribe to these webhook topics in your Shopify app:

1. **fulfillments/create** → `https://your-domain.com/webhooks/fulfillments/create`
2. **fulfillments/update** → `https://your-domain.com/webhooks/fulfillments/update`

### Configuration via `shopify.app.toml`

```toml
[[webhooks.subscriptions]]
topics = ["fulfillments/create"]
uri = "/webhooks/fulfillments/create"

[[webhooks.subscriptions]]
topics = ["fulfillments/update"]
uri = "/webhooks/fulfillments/update"
```

### Configuration via Shopify Admin

1. Go to Settings → Notifications → Webhooks
2. Click "Create webhook"
3. Select event: "Fulfillment creation"
4. URL: `https://your-domain.com/webhooks/fulfillments/create`
5. Format: JSON
6. Repeat for "Fulfillment update"

## Example Webhook Payload

### fulfillments/create

```json
{
  "id": 123456,
  "order_id": 820982911946154508,
  "status": "success",
  "created_at": "2025-10-14T00:00:00-05:00",
  "updated_at": "2025-10-14T00:00:00-05:00",
  "tracking_company": "New Zealand Post",
  "tracking_number": "0079421039261693147",
  "tracking_url": "https://track.nzpost.co.nz/track/0079421039261693147",
  "tracking_urls": ["https://track.nzpost.co.nz/track/0079421039261693147"],
  "shipment_status": "in_transit",
  "location_id": 655441491,
  "line_items": [
    {
      "id": 487817672276298554,
      "variant_id": 49148385,
      "title": "Mayfield Float Framed Canvas",
      "quantity": 1,
      "sku": "HBFX.CANVAS.S14.2987RAW.NM.CANV",
      "price": "179.00"
    },
    {
      "id": 487817672276298555,
      "variant_id": 49148386,
      "title": "Lennon Skinny Framed Print",
      "quantity": 1,
      "sku": "FXMS11.242.4.67",
      "price": "139.00"
    }
  ],
  "origin_address": {
    "name": "Framefox HQ"
  }
}
```

## Testing the Implementation

### 1. Test Webhook Locally

Use `curl` to simulate a Shopify webhook:

```bash
curl -X POST http://localhost:3000/webhooks/fulfillments/create \
  -H "Content-Type: application/json" \
  -H "X-Shopify-Shop-Domain: your-store.myshopify.com" \
  -d '{
    "id": 123456,
    "order_id": "YOUR_SHOPIFY_ORDER_ID",
    "status": "success",
    "created_at": "2025-10-14T00:00:00-05:00",
    "tracking_company": "New Zealand Post",
    "tracking_number": "0079421039261693147",
    "tracking_url": "https://track.nzpost.co.nz/track/0079421039261693147",
    "line_items": [
      {
        "id": "YOUR_SHOPIFY_LINE_ITEM_ID",
        "quantity": 1
      }
    ],
    "origin_address": {
      "name": "Framefox HQ"
    }
  }'
```

### 2. Test in Rails Console

```ruby
# Find an order with shopify_remote_order_id
order = Order.find_by(shopify_remote_order_id: "XXXXX")

# Simulate fulfillment data
fulfillment_data = {
  "id" => "123456",
  "order_id" => order.shopify_remote_order_id,
  "status" => "success",
  "tracking_company" => "New Zealand Post",
  "tracking_number" => "0079421039261693147",
  "tracking_url" => "https://track.nzpost.co.nz/track/0079421039261693147",
  "line_items" => order.order_items.map { |item|
    { "id" => item.shopify_remote_line_item_id, "quantity" => 1 }
  }
}

# Create fulfillment
service = FulfillmentService.new(order: order, fulfillment_data: fulfillment_data)
fulfillment = service.create_fulfillment

# Check results
fulfillment.persisted? # => true
order.reload.fulfillment_status # => :fulfilled or :partially_fulfilled
order.fulfilled_items_count # => count of fulfilled items
```

### 3. Verify UI

1. Navigate to an order: `/orders/:id`
2. You should see:
   - Unfulfilled items section (if any items not yet fulfilled)
   - Fulfilled sections (one per fulfillment) with:
     - Green "Fulfilled (X)" badge
     - Location name
     - Fulfillment ID
     - Date fulfilled
     - Tracking information with clickable link
     - List of fulfilled items

## Data Flow

1. **Shopify creates fulfillment** → Sends webhook to `/webhooks/fulfillments/create`
2. **Webhook controller** receives request → Parses JSON payload
3. **Controller** finds order by `shopify_remote_order_id`
4. **FulfillmentService** creates fulfillment record
5. **Service** creates fulfillment_line_items by matching `shopify_remote_line_item_id`
6. **Service** checks if order is fully fulfilled → updates order state to `fulfilled` if yes
7. **Service** logs activity to order timeline
8. **UI** displays fulfillments grouped separately from unfulfilled items

## Order State Transitions

```
draft → in_production → fulfilled
  ↓           ↓
cancelled   cancelled
  ↓
draft (reopen)
```

**Fulfilled State**

- Automatically triggered when all active order items are fully fulfilled
- Guard: `fully_fulfilled?` returns true
- Can only transition from `in_production` state

## Key Features

### Multiple Fulfillments Per Order

- Supports partial fulfillments (e.g., 2 items ship now, 1 item ships later)
- Each fulfillment is tracked independently
- UI shows each fulfillment in its own section

### Tracking Information

- Stores carrier name, tracking number, and tracking URL
- Displays clickable tracking links in UI
- Supports fulfillments without tracking info

### Fulfillment Status Inference

- No separate "partially_fulfilled" state in AASM
- Status inferred from fulfillment data:
  - `unfulfilled`: No fulfillments exist
  - `partially_fulfilled`: Some items fulfilled, but not all
  - `fulfilled`: All items completely fulfilled (AASM state transitions)

### Item-Level Tracking

- Each order item knows its fulfilled/unfulfilled quantity
- Supports partial fulfillment of individual items
- UI shows correct quantity for each section

## Next Steps

### Production Checklist

- [ ] Implement HMAC webhook verification in `Webhooks::FulfillmentsController#verify_shopify_webhook`
- [ ] Configure webhook subscriptions in Shopify Partner Dashboard
- [ ] Test with real Shopify fulfillments
- [ ] Add fulfillment creation UI (future: allow manual fulfillments)
- [ ] Add fulfillment cancellation handling
- [ ] Consider tracking fulfillment events (shipment status updates)

### Optional Enhancements

- Add fulfillment filtering/search on orders index
- Show fulfillment status badges on orders list
- Add email notifications when items are fulfilled
- Track estimated delivery dates
- Support manual fulfillment creation from admin panel

## Troubleshooting

### Webhook Not Creating Fulfillment

1. Check Rails logs for webhook reception
2. Verify `shopify_remote_order_id` exists on order
3. Verify `shopify_remote_line_item_id` exists on order items
4. Check `FulfillmentService` errors in logs

### Order Not Transitioning to Fulfilled

1. Check if all items are fully fulfilled: `order.fully_fulfilled?`
2. Verify order is in `in_production` state
3. Check if `may_fulfill?` returns true
4. Look for AASM guard failures in logs

### Line Items Not Matching

- Ensure `shopify_remote_line_item_id` is set on order items (this should happen during order import)
- Check OrderProductionService to ensure it's setting this field correctly
- Verify webhook payload contains correct line item IDs

## Files Modified/Created

### Created

- `db/migrate/20251014024226_create_fulfillments.rb`
- `db/migrate/20251014024229_create_fulfillment_line_items.rb`
- `app/models/fulfillment.rb`
- `app/models/fulfillment_line_item.rb`
- `app/services/fulfillment_service.rb`
- `app/controllers/webhooks/fulfillments_controller.rb`
- `FULFILLMENT_IMPLEMENTATION.md` (this file)

### Modified

- `app/models/order.rb` - Added fulfillments association, fulfilled state, fulfillment tracking methods
- `app/models/order_item.rb` - Added fulfillment tracking methods
- `app/controllers/orders_controller.rb` - Added fulfillments to eager loading
- `app/controllers/admin/orders_controller.rb` - Added fulfillments to eager loading
- `app/helpers/application_helper.rb` - Added fulfilled state to badge helper
- `app/views/orders/show.html.erb` - Grouped items by fulfillment status
- `config/routes.rb` - Added fulfillment webhook routes
- `db/schema.rb` - Auto-updated by migrations
