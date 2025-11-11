# Webhook Architecture

## Overview

Framefox Connect has **two completely separate webhook systems** that must not overlap or interfere with each other:

1. **Merchant Store Webhooks** - From stores that install the Framefox Connect app
2. **Production Store Webhooks** - From Framefox's own production Shopify stores

## Webhook Systems

### 1. Merchant Store Webhooks

These webhooks come from **merchant stores that install your app**. They require HMAC verification for security.

#### Purpose
- Import new orders from merchant stores
- Sync products from merchant stores
- Handle app uninstall events
- Process GDPR compliance requests

#### Controllers
All use `ShopifyWebhookVerification` concern for HMAC security:

| Webhook Topic | Controller | Action | Purpose |
|--------------|------------|---------|---------|
| `app/uninstalled` | `Webhooks::AppController` | `uninstalled` | Merchant uninstalls app (returns 200 even if store not found) |
| `orders/create` | `Webhooks::OrdersController` | `create` | **New order from merchant store** (returns 404 if store not found) |
| `products/create` | `Webhooks::ProductsController` | `create` | New product in merchant store (returns 404 if store not found) |
| `products/update` | `Webhooks::ProductsController` | `update` | Product updated in merchant store (returns 404 if store not found) |
| `customers/data_request` | `Webhooks::GdprController` | `customers_data_request` | GDPR data request (returns 200 even if store not found) |
| `customers/redact` | `Webhooks::GdprController` | `customers_redact` | GDPR customer deletion (returns 200 even if store not found) |
| `shop/redact` | `Webhooks::GdprController` | `shop_redact` | GDPR shop deletion (returns 200 even if store not found) |

#### Security
✅ **HMAC-SHA256 verification required**
- Validates webhook authenticity
- Prevents unauthorized access
- Required for App Store approval

#### Registration
Register these webhooks in the **Shopify Partner Dashboard** for your app, or via `shopify.app.toml`.

---

### 2. Production Store Webhooks

These webhooks come from **Framefox's own production Shopify stores** (internal system). They do NOT require HMAC verification.

#### Purpose
- Notify when Framefox has charged a merchant for their order
- Track fulfillment status from Framefox production
- Internal system communication

#### Controllers
Do NOT use HMAC verification (skip authenticity token only):

| Webhook Topic | Controller | Action | Purpose |
|--------------|------------|---------|---------|
| `orders/paid` | `Webhooks::ProductionOrdersController` | `paid` | **Framefox charged merchant** |
| `fulfillments/create` | `Webhooks::ProductionFulfillmentsController` | `create` | Framefox created fulfillment |
| `fulfillments/update` | `Webhooks::ProductionFulfillmentsController` | `update` | Framefox updated fulfillment |

#### Security
❌ **No HMAC verification** (internal system)
- Uses `skip_before_action :verify_authenticity_token`
- Trusts requests from Framefox production stores
- Not exposed to external merchants

#### Registration
Register these webhooks in **Framefox's production Shopify store admin**:
1. Go to Settings → Notifications → Webhooks
2. Create webhooks pointing to `connect.framefox.com/webhooks/*`

---

## Important Distinctions

### orders/create vs orders/paid

These are **completely different** and must not overlap:

| Webhook | Source | Purpose | HMAC? |
|---------|--------|---------|-------|
| `orders/create` | **Merchant store** | New order placed in merchant's store | ✅ Yes |
| `orders/paid` | **Framefox production** | Framefox charged merchant for order | ❌ No |

**Flow:**
1. Customer places order in merchant store → `orders/create` webhook → Import order
2. Merchant submits order to Framefox production
3. Framefox charges merchant → `orders/paid` webhook → Mark payment captured

### Why Separate Controllers?

We use separate controllers to:
1. **Prevent security conflicts** - Can't apply HMAC to production webhooks
2. **Clear separation of concerns** - Merchant vs Production systems
3. **Independent evolution** - Change one without affecting the other
4. **Explicit documentation** - Clear which system each webhook serves

## Route Configuration

```ruby
namespace :webhooks do
  # MERCHANT STORE WEBHOOKS (with HMAC verification)
  post "app/uninstalled", to: "app#uninstalled"
  post "orders/create", to: "orders#create"  # NEW orders from merchants
  post "products/create", to: "products#create"
  post "products/update", to: "products#update"
  post "customers/data_request", to: "gdpr#customers_data_request"
  post "customers/redact", to: "gdpr#customers_redact"
  post "shop/redact", to: "gdpr#shop_redact"
  
  # PRODUCTION STORE WEBHOOKS (no HMAC verification)
  post "orders/paid", to: "production_orders#paid"  # Framefox charged merchant
  post "fulfillments/create", to: "production_fulfillments#create"
  post "fulfillments/update", to: "production_fulfillments#update"
end
```

## Testing

### Merchant Store Webhooks
Use proper HMAC signatures for testing:

```bash
DATA='{"id":12345,"test":"data"}'
HMAC=$(echo -n "$DATA" | openssl dgst -sha256 -hmac "$SHOPIFY_API_SECRET" -binary | base64)

curl -X POST http://localhost:3000/webhooks/orders/create \
  -H "Content-Type: application/json" \
  -H "X-Shopify-Hmac-Sha256: $HMAC" \
  -H "X-Shopify-Shop-Domain: merchant-store.myshopify.com" \
  -d "$DATA"
```

### Production Store Webhooks
No HMAC required:

```bash
curl -X POST http://localhost:3000/webhooks/orders/paid \
  -H "Content-Type: application/json" \
  -d '{"id":12345,"financial_status":"paid"}'
```

## Error Handling

### 404 Not Found Behavior

Most operational webhooks return **404 Not Found** when the store doesn't exist:
- `orders/create` - Returns 404 if store not found
- `products/create` - Returns 404 if store not found  
- `products/update` - Returns 404 if store not found

This is correct because if orders/products come from a non-existent store, something is wrong and we can't process them.

**Exceptions (Return 200 OK even if store not found):**

These webhooks return **200 OK** even if the store is not found:
- `app/uninstalled` - Store might already be deleted or marked inactive
- `customers/data_request` - GDPR compliance, acknowledge even if store gone
- `customers/redact` - GDPR compliance, acknowledge even if store gone
- `shop/redact` - GDPR compliance, acknowledge and delete if exists

**Why return 200 OK?**
- Store might have already been deleted
- Could be a duplicate webhook
- We want to acknowledge receipt so Shopify stops retrying
- GDPR webhooks must always be acknowledged per compliance requirements

### Idempotency

All webhooks are idempotent (safe to receive multiple times):

**Merchant Store Webhooks:**
- `app/uninstalled`: Checks if store exists before updating, returns 200 OK if already gone
- `orders/create`: Checks if order already imported
- `products/create` / `products/update`: Can be processed multiple times safely
- `customers/data_request`: Returns 200 OK even if store not found
- `customers/redact`: Returns 200 OK even if store not found
- `shop/redact`: Deletes store if exists, returns 200 OK if already deleted

**Production Store Webhooks:**
- `orders/paid`: Checks if payment already captured
- `fulfillments/create`: Checks if fulfillment already exists
- `fulfillments/update`: Can be processed multiple times safely

## Monitoring

Track both systems separately:

```ruby
# Merchant webhook failures (should track HMAC rejections)
grep "Shopify webhook rejected" log/production.log | grep -v "production_"

# Production webhook activity (internal system)
grep "production_orders\|production_fulfillments" log/production.log

# Duplicate/already processed webhooks (normal behavior)
grep "already deleted or duplicate webhook" log/production.log
```

## Related Files

### Merchant Store Webhooks
- `app/controllers/concerns/shopify_webhook_verification.rb` - HMAC verification
- `app/controllers/webhooks/app_controller.rb`
- `app/controllers/webhooks/orders_controller.rb`
- `app/controllers/webhooks/products_controller.rb`
- `app/controllers/webhooks/gdpr_controller.rb`

### Production Store Webhooks
- `app/controllers/webhooks/production_orders_controller.rb`
- `app/controllers/webhooks/production_fulfillments_controller.rb`

## Summary

| Aspect | Merchant Store Webhooks | Production Store Webhooks |
|--------|------------------------|--------------------------|
| **Source** | Stores that install the app | Framefox's own Shopify stores |
| **HMAC Verification** | ✅ Required | ❌ Not required |
| **Purpose** | App functionality | Internal system communication |
| **Registration** | Partner Dashboard / shopify.app.toml | Framefox store admin |
| **Security Level** | High (external) | Lower (internal trusted) |
| **App Store Requirement** | Yes | No |

