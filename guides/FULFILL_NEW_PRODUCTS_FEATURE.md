# Fulfill New Products Feature

## Overview

This feature allows store owners to automatically enable fulfillment for new products and variants when they are imported from their connected stores.

## Database Changes

### Migration: `AddFulfillNewProductsToStores`

- **Field**: `fulfill_new_products` (boolean)
- **Default**: `false`
- **Location**: `stores` table
- **Purpose**: Controls whether newly imported products/variants should automatically have fulfillment enabled

## User Interface

### Settings Page

Located at: `connections/stores/:id/settings`

The settings page provides two radio button options:

1. **Automatically fulfill new products with Framefox** (`fulfill_new_products = true`)
   - When selected, any new products and variants imported from the store will have `fulfilment_active` set to `true`
   - Existing products/variants are not affected
2. **Ignore new products (do not fulfill with Framefox)** (`fulfill_new_products = false`) - Default
   - New products and variants will be imported with `fulfilment_active = false`
   - Users must manually enable fulfillment for each product/variant

### How to Access

1. Navigate to Store Connections dashboard
2. Select a store
3. Click the "Settings" button in the page header
4. Scroll to "Synchronization" section
5. Choose your preferred option
6. Click "Save Changes"

## Implementation Details

### Product Import Service

File: `app/services/shopify_product_sync_service.rb`

#### For New Products

When a product is imported for the first time:

```ruby
if is_new_product && store.fulfill_new_products
  product.fulfilment_active = true
  Rails.logger.info "Auto-enabling fulfillment for new product: #{product.title}"
end
```

#### For New Variants

When a variant is imported for the first time:

```ruby
if is_new_variant && store.fulfill_new_products
  variant.fulfilment_active = true
  Rails.logger.info "Auto-enabling fulfillment for new variant: #{variant.title}"
end
```

### Important Notes

1. This setting only applies to **new** products and variants (first import)
2. Existing products/variants are **not affected** when the setting is changed
3. Re-syncing existing products will not change their fulfillment status
4. The setting is checked at import time using `product.new_record?` and `variant.new_record?`

## Routes

```ruby
patch 'connections/stores/:id/update_fulfill_new_products'
```

## Controller Action

File: `app/controllers/connections/stores_controller.rb`

```ruby
def update_fulfill_new_products
  if @store.update(fulfill_new_products_params)
    redirect_to settings_connections_store_path(@store),
                notice: "Fulfillment settings updated successfully."
  else
    redirect_to settings_connections_store_path(@store),
                alert: "Failed to update settings."
  end
end

private

def fulfill_new_products_params
  params.require(:store).permit(:fulfill_new_products)
end
```

## Use Cases

### Use Case 1: Onboarding a New Store

A merchant connects a new Shopify store with 200 products. They enable "Automatically fulfill new products with Framefox" before running their first product sync. All 200 products and their variants are imported with fulfillment enabled.

### Use Case 2: Selective Fulfillment

A merchant wants to review each product before enabling fulfillment. They keep the default setting "Ignore new products". After sync, they manually enable fulfillment for specific products through the product detail pages.

### Use Case 3: Adding New Products

A merchant has an established store with the auto-fulfill setting enabled. When they add new products to their Shopify store, the next sync will automatically enable fulfillment for these new additions while leaving existing product settings unchanged.

## Testing

To test this feature:

1. Create a new store or use an existing one
2. Navigate to the store's settings page
3. Select "Automatically fulfill new products with Framefox"
4. Click "Save Changes"
5. Add a new product to the connected platform (e.g., Shopify)
6. Trigger a product sync
7. Verify the new product has `fulfilment_active = true`
8. Verify existing products remain unchanged

## Future Enhancements

Potential improvements for this feature:

1. **Bulk Update**: Add ability to apply the setting retroactively to existing products
2. **Webhook Integration**: Auto-enable fulfillment when product webhooks are received
3. **Conditional Logic**: Enable fulfillment based on product type, tags, or other criteria
4. **Per-Product Override**: Allow manual override of auto-fulfillment at the product level
5. **Multi-Platform**: Extend implementation to Wix and Squarespace when those integrations are built

## Related Files

- Migration: `db/migrate/20251016012337_add_fulfill_new_products_to_stores.rb`
- Service: `app/services/shopify_product_sync_service.rb`
- Controller: `app/controllers/connections/stores_controller.rb`
- View: `app/views/connections/stores/settings.html.erb`
- Routes: `config/routes.rb`
- Model: `app/models/store.rb`
