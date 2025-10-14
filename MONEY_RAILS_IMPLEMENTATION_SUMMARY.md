# Money Rails Implementation Summary

## Overview

Successfully converted all cost fields to use money-rails gem with `_cents` integer columns, added production cost tracking fields, and removed all original order cost displays from the UI.

## Database Changes

### Migration 1: Convert existing cost columns to \_cents

**File:** `db/migrate/20251014212309_convert_cost_columns_to_money_rails.rb`

**Orders table columns converted:**

- `subtotal_price` (decimal) → `subtotal_price_cents` (integer)
- `total_discounts` (decimal) → `total_discounts_cents` (integer)
- `total_shipping` (decimal) → `total_shipping_cents` (integer)
- `total_tax` (decimal) → `total_tax_cents` (integer)
- `total_price` (decimal) → `total_price_cents` (integer)

**Order items table columns converted:**

- `price` (decimal) → `price_cents` (integer)
- `total` (decimal) → `total_cents` (integer)
- `discount_amount` (decimal) → `discount_amount_cents` (integer)
- `tax_amount` (decimal) → `tax_amount_cents` (integer)

**Process:**

1. Added new `_cents` columns as integers
2. Copied existing data (multiplied by 100)
3. Removed old check constraints
4. Removed old decimal columns
5. Added new check constraints for non-negative values

### Migration 2: Add production cost columns

**File:** `db/migrate/20251014212430_add_production_cost_columns.rb`

**Orders table:**

- `production_subtotal_cents` (integer, default: 0)
- `production_shipping_cents` (integer, default: 0)
- `production_total_cents` (integer, default: 0)

**Order items table:**

- `production_cost_cents` (integer, default: 0)

All production cost columns include check constraints to ensure non-negative values.

## Model Updates

### Order Model (`app/models/order.rb`)

**Added monetize declarations:**

```ruby
# Original order costs (not displayed in UI)
monetize :subtotal_price_cents, with_currency: :currency
monetize :total_discounts_cents, with_currency: :currency
monetize :total_shipping_cents, with_currency: :currency
monetize :total_tax_cents, with_currency: :currency
monetize :total_price_cents, with_currency: :currency

# Production costs from Shopify order
monetize :production_subtotal_cents, with_currency: :currency
monetize :production_shipping_cents, with_currency: :currency
monetize :production_total_cents, with_currency: :currency
```

**Updated validations:**

- Changed validations to reference `_cents` columns
- Added validations for production cost columns

### OrderItem Model (`app/models/order_item.rb`)

**Added monetize declarations:**

```ruby
# Original order item costs (not displayed in UI)
monetize :price_cents, with_currency: -> { order.currency }
monetize :total_cents, with_currency: -> { order.currency }
monetize :discount_amount_cents, with_currency: -> { order.currency }
monetize :tax_amount_cents, with_currency: -> { order.currency }

# Production cost from Shopify order
monetize :production_cost_cents, with_currency: -> { order.currency }
```

**Updated methods:**

- Updated validations to reference `_cents` columns
- Modified `unit_price_with_tax` to return Money objects

## Service Updates

### ImportOrderService (`app/services/import_order_service.rb`)

**Changes in all methods that create/update orders and order items:**

- `import_order`: Converts Shopify decimal amounts to cents before saving
- `resync_order_data`: Same conversion applied
- `import_order_items`: Converts line item amounts to cents
- `update_order_item`: Converts amounts to cents
- `create_order_item`: Converts amounts to cents

**Conversion pattern:**

```ruby
subtotal_price_cents: (extract_money_amount(order_data, "subtotalPriceSet") * 100).to_i
```

### OrderProductionService (`app/services/order_production_service.rb`)

**Updated GraphQL query in `finalize_draft_order`:**

- Added `subtotalPriceSet`, `totalShippingPriceSet`, `totalPriceSet` to order query
- Added `originalUnitPriceSet` to line items query

**Added helper method:**

```ruby
def extract_money_amount_from_set(price_set)
  amount_str = price_set&.dig("shopMoney", "amount")
  amount_str ? BigDecimal(amount_str) : BigDecimal(0)
end
```

**Updated order completion:**

- Extracts production costs from Shopify order response
- Saves production costs when order is completed:
  - `production_subtotal_cents`
  - `production_shipping_cents`
  - `production_total_cents`

**Updated `save_line_item_ids`:**

- Now also saves `production_cost_cents` for each order item from line item price

## View Updates

### Orders Show Page (`app/views/orders/show.html.erb`)

**Removed:**

- Line 466: Removed display of `item.price` for non-fulfillable items

**Retained:**

- JavaScript data attributes still pass `price` (now as Money object with `.to_f`)
- These are for internal tracking only, not displayed to users

### Orders Index Page (`app/views/orders/index.html.erb`)

**Removed:**

- Entire "Total" column (both header and body cells)
- No cost information displayed in order list

### Email Templates

**Updated both HTML and text versions:**

- `app/views/order_mailer/draft_imported.html.erb`
- `app/views/order_mailer/draft_imported.text.erb`
- Removed price display from order item listings
- Now only shows quantity, not unit prices

## Key Features

### Original Order Costs

- **Source:** Imported from platform (Shopify) when order is created
- **Storage:** Stored in `_cents` integer columns
- **Currency:** Uses the order's currency field
- **Display:** **NEVER shown in UI** - internal tracking only
- **Access:** Available via money-rails methods (e.g., `order.subtotal_price` returns Money object)

### Production Costs

- **Source:** Populated from Shopify order created by production system
- **When:** Set when draft order is completed in `OrderProductionService`
- **Purpose:** Track actual production costs from the manufacturing system
- **Storage:**
  - Order level: subtotal, shipping, total
  - Item level: unit cost
- **Display:** Can be shown in UI if needed (currently not displayed)

## Testing Checklist

- [x] Migrations run successfully
- [x] No linter errors in updated files
- [x] All references to old column names removed from app code
- [x] No cost displays in views (except internal JS data attributes)
- [ ] Test order import from Shopify
- [ ] Test sending order to production
- [ ] Verify production costs populate correctly
- [ ] Verify Money object methods work correctly in console
- [ ] Test email templates render correctly

## Money Object Usage

With money-rails, you can now use:

```ruby
# Get formatted money
order.subtotal_price.format  # e.g., "$10.50"

# Perform arithmetic
order.subtotal_price + order.total_shipping

# Get cents value
order.subtotal_price.cents  # e.g., 1050

# Convert to float (for calculations)
order.subtotal_price.to_f  # e.g., 10.5

# Access cents directly
order.subtotal_price_cents  # e.g., 1050
```

## Notes

- The `currency` column already existed on orders table, so no migration needed
- All money columns use the order's currency field
- Check constraints ensure all cost values are non-negative
- Migrations are reversible with proper down methods
