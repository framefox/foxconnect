# Shopify Payment Webhook Setup Guide

## Overview

This guide explains how to set up the Shopify `orders/paid` webhook to automatically update payment status in your Rails application when orders are paid in Shopify.

## What It Does

When a customer pays for an order in Shopify, the webhook will:

1. Send a POST request to your Rails app
2. Find the corresponding order by `shopify_remote_order_id`
3. Update the `production_paid_at` timestamp
4. Log the payment activity in the order history

## Webhook Registration

### Option A: Via Shopify Admin (Quick Setup)

1. Log in to your Shopify store admin
2. Go to **Settings** → **Notifications**
3. Scroll down to **Webhooks** section
4. Click **Create webhook**
5. Configure:
   - **Event**: Select "Order payment"
   - **Format**: JSON
   - **URL**: `https://yourdomain.com/orders/paid`
   - **API Version**: Latest stable version
6. Click **Save**

### Option B: Via Rails Console (Programmatic)

```ruby
# In Rails console or create a rake task
store = Store.find_by(shopify_domain: 'your-store.myshopify.com')

# Set up Shopify API session
ShopifyAPI::Context.activate_session(
  ShopifyAPI::Session.new(
    shop: store.shopify_domain,
    access_token: store.shopify_token
  )
)

# Create the webhook
webhook = ShopifyAPI::Webhook.new
webhook.topic = "orders/paid"
webhook.address = "https://yourdomain.com/orders/paid"
webhook.format = "json"
webhook.save!

puts "Webhook created with ID: #{webhook.id}"
```

### Option C: Create a Rake Task (Recommended for Production)

Create `lib/tasks/shopify_webhooks.rake`:

```ruby
namespace :shopify do
  namespace :webhooks do
    desc "Register orders/paid webhook for all active stores"
    task register_payment: :environment do
      Store.active.where(platform: 'shopify').find_each do |store|
        begin
          session = ShopifyAPI::Session.new(
            shop: store.shopify_domain,
            access_token: store.shopify_token
          )
          ShopifyAPI::Context.activate_session(session)

          webhook = ShopifyAPI::Webhook.new
          webhook.topic = "orders/paid"
          webhook.address = "#{ENV['APP_URL']}/orders/paid"
          webhook.format = "json"

          if webhook.save
            puts "✓ Registered webhook for #{store.shopify_domain}"
          else
            puts "✗ Failed for #{store.shopify_domain}: #{webhook.errors.full_messages}"
          end
        rescue => e
          puts "✗ Error for #{store.shopify_domain}: #{e.message}"
        end
      end
    end

    desc "List all registered webhooks for a store"
    task :list, [:shop_domain] => :environment do |t, args|
      store = Store.find_by(shopify_domain: args[:shop_domain])

      session = ShopifyAPI::Session.new(
        shop: store.shopify_domain,
        access_token: store.shopify_token
      )
      ShopifyAPI::Context.activate_session(session)

      webhooks = ShopifyAPI::Webhook.all
      webhooks.each do |webhook|
        puts "\nWebhook ID: #{webhook.id}"
        puts "Topic: #{webhook.topic}"
        puts "Address: #{webhook.address}"
        puts "Format: #{webhook.format}"
      end
    end
  end
end
```

Run with:

```bash
rake shopify:webhooks:register_payment
rake shopify:webhooks:list[your-store.myshopify.com]
```

## Testing the Webhook

### 1. Using Shopify Admin (Easiest)

1. Go to **Settings** → **Notifications** → **Webhooks**
2. Find your "Order payment" webhook
3. Click **Send test notification**
4. Check your Rails logs for the webhook processing

### 2. Using ngrok for Local Development

```bash
# Start ngrok
ngrok http 3000

# Update webhook URL in Shopify to your ngrok URL
# e.g., https://abc123.ngrok.io/orders/paid

# Create a test order in Shopify and mark it as paid
```

### 3. Manual Testing with curl

```bash
# Note: You'll need a valid HMAC signature for production
curl -X POST https://yourdomain.com/orders/paid \
  -H "Content-Type: application/json" \
  -H "X-Shopify-Topic: orders/paid" \
  -d '{
    "id": 123456789,
    "email": "customer@example.com",
    "financial_status": "paid",
    "total_price": "199.99",
    "currency": "USD",
    "payment_gateway_names": ["shopify_payments"]
  }'
```

## Monitoring

### Check Webhook Logs

```ruby
# In Rails console
order = Order.find_by(shopify_remote_order_id: "123456789")
order.production_paid_at
order.payment_captured?
order.recent_activities
```

### Check Rails Logs

```bash
# Development
tail -f log/development.log | grep "Order payment"

# Production
tail -f log/production.log | grep "Order payment"
```

## Troubleshooting

### Webhook Not Receiving Requests

1. **Verify webhook is registered**: Check in Shopify Admin → Settings → Notifications → Webhooks
2. **Check URL is correct**: Should be `https://yourdomain.com/orders/paid`
3. **Verify SSL certificate**: Shopify requires HTTPS with valid SSL
4. **Check firewall**: Ensure your server accepts requests from Shopify's IP ranges

### Order Not Found Error

- Verify the order exists in your database with matching `shopify_remote_order_id`
- Check that the order was created/synced from Shopify before payment webhook fired

### Duplicate Webhook Calls

- The `mark_payment_captured!` method includes idempotency checks
- Already paid orders will return HTTP 200 with "Payment already captured" message

### HMAC Verification (TODO)

Currently, HMAC verification is not implemented. To add it:

1. Get your webhook secret from Shopify
2. Implement verification in `verify_shopify_webhook` method:

```ruby
def verify_shopify_webhook
  request.body.rewind
  data = request.body.read
  hmac_header = request.headers['X-Shopify-Hmac-Sha256']

  webhook_secret = ENV['SHOPIFY_WEBHOOK_SECRET']
  computed_hmac = Base64.strict_encode64(
    OpenSSL::HMAC.digest('sha256', webhook_secret, data)
  )

  unless ActiveSupport::SecurityUtils.secure_compare(computed_hmac, hmac_header)
    render json: { error: 'Unauthorized' }, status: :unauthorized
  end
end
```

## Webhook Payload Example

```json
{
  "id": 820982911946154508,
  "email": "customer@example.com",
  "financial_status": "paid",
  "fulfillment_status": null,
  "total_price": "199.99",
  "currency": "USD",
  "created_at": "2024-01-15T10:30:00-05:00",
  "updated_at": "2024-01-15T10:35:00-05:00",
  "payment_gateway_names": ["shopify_payments"],
  "line_items": [...],
  "shipping_address": {...}
}
```

## Required Shopify Permissions

Ensure your Shopify app has the following scopes:

- `read_orders` (to receive order webhooks)

## Next Steps

1. Register the webhook in Shopify Admin or via API
2. Test with a real or test order
3. Monitor logs for successful webhook processing
4. Implement HMAC verification for production
5. Set up error monitoring/alerting for failed webhooks
