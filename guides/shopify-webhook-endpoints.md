# Shopify Webhook Endpoints

## Production URLs

Replace `connect.framefox.com` with your actual domain.

### Required Webhooks (Mandatory for App Store Approval)

These webhooks are **required** by Shopify for App Store approval:

| Webhook Topic | URL | Description |
|--------------|-----|-------------|
| `app/uninstalled` | `https://connect.framefox.com/webhooks/app/uninstalled` | Triggered when a merchant uninstalls your app |
| `customers/data_request` | `https://connect.framefox.com/webhooks/customers/data_request` | GDPR: Customer requests their data |
| `customers/redact` | `https://connect.framefox.com/webhooks/customers/redact` | GDPR: Customer requests data deletion |
| `shop/redact` | `https://connect.framefox.com/webhooks/shop/redact` | GDPR: Shop owner closes their store |

### Merchant Store Webhooks (For App Functionality)

These webhooks come from merchant stores that install your app. They require HMAC verification.

| Webhook Topic | URL | Purpose |
|--------------|-----|---------|
| `orders/create` | `https://connect.framefox.com/webhooks/orders/create` | Import new orders from merchant stores |
| `products/create` | `https://connect.framefox.com/webhooks/products/create` | Sync new products from merchant stores |
| `products/update` | `https://connect.framefox.com/webhooks/products/update` | Sync product updates from merchant stores |

### Production Store Webhooks (Internal System)

⚠️ **Important**: These webhooks come from Framefox's own production Shopify stores (not merchant stores) and do NOT require HMAC verification. They are a completely separate system.

| Webhook Topic | URL | Purpose |
|--------------|-----|---------|
| `orders/paid` | `https://connect.framefox.com/webhooks/orders/paid` | Framefox production charged the merchant |
| `fulfillments/create` | `https://connect.framefox.com/webhooks/fulfillments/create` | Framefox production created fulfillment |
| `fulfillments/update` | `https://connect.framefox.com/webhooks/fulfillments/update` | Framefox production updated fulfillment |

**Registration**: Configure these in **Framefox's production Shopify store admin** (not in Partner Dashboard).

## Registering Webhooks

### Option 1: Via Shopify Partner Dashboard

1. Go to your app in the Partner Dashboard
2. Navigate to **Configuration** → **Webhooks**
3. Click **Add webhook** for each endpoint
4. Enter the **Topic** (e.g., `customers/data_request`)
5. Enter the **URL** (e.g., `https://connect.framefox.com/webhooks/customers/data_request`)
6. Set **API Version** to `2025-10` (or latest stable)
7. Click **Save**

### Option 2: Via Shopify CLI

You can define webhooks in your `shopify.app.toml` file:

```toml
[webhooks]
api_version = "2025-10"

[[webhooks.subscriptions]]
topics = [ "app/uninstalled" ]
uri = "/webhooks/app/uninstalled"

[[webhooks.subscriptions]]
topics = [ "customers/data_request" ]
uri = "/webhooks/customers/data_request"

[[webhooks.subscriptions]]
topics = [ "customers/redact" ]
uri = "/webhooks/customers/redact"

[[webhooks.subscriptions]]
topics = [ "shop/redact" ]
uri = "/webhooks/shop/redact"

[[webhooks.subscriptions]]
topics = [ "orders/create" ]
uri = "/webhooks/orders/create"

[[webhooks.subscriptions]]
topics = [ "orders/paid" ]
uri = "/webhooks/orders/paid"

[[webhooks.subscriptions]]
topics = [ "products/create" ]
uri = "/webhooks/products/create"

[[webhooks.subscriptions]]
topics = [ "products/update" ]
uri = "/webhooks/products/update"

[[webhooks.subscriptions]]
topics = [ "fulfillments/create" ]
uri = "/webhooks/fulfillments/create"

[[webhooks.subscriptions]]
topics = [ "fulfillments/update" ]
uri = "/webhooks/fulfillments/update"
```

Then run:
```bash
shopify app deploy
```

### Option 3: Via GraphQL Admin API

You can programmatically register webhooks using the Shopify Admin GraphQL API:

```graphql
mutation {
  webhookSubscriptionCreate(
    topic: CUSTOMERS_DATA_REQUEST
    webhookSubscription: {
      callbackUrl: "https://connect.framefox.com/webhooks/customers/data_request"
      format: JSON
    }
  ) {
    webhookSubscription {
      id
      topic
      endpoint {
        __typename
        ... on WebhookHttpEndpoint {
          callbackUrl
        }
      }
    }
    userErrors {
      field
      message
    }
  }
}
```

## Security

### Merchant Store Webhooks
Protected with:
- **HMAC-SHA256 signature verification** using your app's secret key
- **Shop domain validation** to ensure webhooks come from registered stores
- **Secure comparison** to prevent timing attacks

### Production Store Webhooks
- **No HMAC verification** (internal trusted system)
- Only `skip_before_action :verify_authenticity_token`

See the [Shopify Webhook Security Guide](./shopify-webhook-security.md) and [Webhook Architecture Guide](./webhook-architecture.md) for implementation details.

## Testing Webhooks

### Development Environment

For local testing, you'll need to expose your local server to the internet using a tool like:

- **Shopify CLI** (recommended): `shopify app dev`
- **ngrok**: `ngrok http 3000`
- **Cloudflare Tunnel**: `cloudflared tunnel`

Then update your webhook URLs to use the tunnel URL:
```
https://your-tunnel-url.ngrok.io/webhooks/customers/data_request
```

### Triggering Test Webhooks

Use the Shopify Partner Dashboard to send test webhooks:
1. Go to **Webhooks** in your app configuration
2. Find the webhook you want to test
3. Click **Send test notification**

## Troubleshooting

### Webhook Delivery Failures

Check the Shopify Partner Dashboard for:
- HTTP status codes returned by your endpoints
- Error messages
- Delivery attempts and retries

### Common Issues

| Issue | Solution |
|-------|----------|
| 401 Unauthorized | HMAC verification failed. Check your `SHOPIFY_API_SECRET` |
| 404 Not Found | Store doesn't exist or webhook URL is incorrect |
| 500 Server Error | Check your application logs for errors |
| Timeout | Webhook processing took too long (>5 seconds) |

## Monitoring

Monitor webhook health by tracking:
- Delivery success rate
- Processing time
- Error rates by webhook type
- Failed HMAC verifications

Example monitoring query:
```ruby
# Count webhook deliveries by type today
Rails.logger.grep("webhook received").count

# Count failed HMAC verifications
Rails.logger.grep("HMAC verification failed").count
```

## References

- [Shopify Webhook Documentation](https://shopify.dev/docs/apps/webhooks)
- [GDPR Webhooks](https://shopify.dev/docs/apps/webhooks/configuration/mandatory-webhooks)
- [Webhook Best Practices](https://shopify.dev/docs/apps/webhooks/best-practices)

