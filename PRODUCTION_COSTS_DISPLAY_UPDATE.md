# Production Costs Display Update

## Overview

Added display of production costs for line items and a comprehensive Payment Summary section showing order financials.

## Changes Made

### 1. Order Items - Production Cost Display

**File:** `app/javascript/components/OrderItemCard.js`

Added production cost display for each line item:

- Unit cost shown next to quantity (e.g., "$299.00 each")
- Total line item cost shown below (quantity × unit cost)
- Only displays when `production_cost > 0` (i.e., after order is sent to production)

**Visual Example:**

```
Mayfield Float Framed Canvas
SKU: HBFX.CANVAS.S25.2987RAW.NM.CANV
Qty: 1    $299.00 each
$299.00
```

### 2. Order View - Production Cost Data

**File:** `app/views/orders/show.html.erb`

Updated all order item cards to pass `production_cost` to React component:

- Unfulfilled items section (line 259)
- Fulfillment line items section (line 340)
- Draft items section (line 402)
- Removed items section (line 514)

**Data structure:**

```ruby
item: {
  # ... existing fields ...
  production_cost: item.production_cost.to_f,
  # ... other fields ...
}
```

### 3. Payment Summary Section

**File:** `app/views/orders/show.html.erb`

Added a new "Payment" card in the sidebar (lines 548-594) that displays:

**Fields shown:**

- **Subtotal**: Production subtotal from Shopify order
- **Discount**: Only shown if `total_discounts_cents > 0`
- **Shipping**: Production shipping cost
- **Tax**: Only shown if `total_tax_cents > 0`
- **Total**: Production total (bold)
- **Item count**: Number of items in order

**Visibility:**

- Only shown when order is `in_production?` or `fulfilled?`
- Hidden for draft orders (no production costs yet)

**Example Output:**

```
Payment
Subtotal       $537.00
Discount       -$0.00
Shipping       $0.00
Tax            $80.55
─────────────────────
Total          $617.55
3 items
```

## Money Object Usage

All monetary values use the money-rails Money objects:

- `@order.production_subtotal.format` → "$537.00"
- `@order.production_shipping.format` → "$0.00"
- `@order.production_total.format` → "$617.55"
- `item.production_cost.to_f` → 299.0 (for JavaScript)

## UI/UX Details

### OrderItemCard Component

- Production costs displayed in slate-600 color (secondary text)
- Unit cost shown inline with quantity
- Line total shown below as medium-weight text
- Automatically formatted based on order currency

### Payment Summary

- Clean, professional layout matching Shopify's design
- Proper spacing and alignment
- Border between line items and total
- Conditional display of optional fields (discount, tax)
- Displays item count for quick reference

## Implementation Notes

1. **Production costs only**: These are the actual costs from the Shopify order created by the production system, not the original order costs from the customer

2. **When costs appear**: Production costs are populated when:

   - Order is sent to production (`OrderProductionService`)
   - Draft order is completed in Shopify
   - Costs are extracted from Shopify's GraphQL response

3. **Currency handling**: All costs automatically use the order's currency field via money-rails monetization

4. **Zero cost handling**:
   - Line items: production_cost > 0 check ensures display only when populated
   - Payment summary: conditional rendering for discount and tax

## Testing Checklist

- [x] No linter errors in modified files
- [ ] Order items display production costs after sending to production
- [ ] Payment summary appears for in_production orders
- [ ] Payment summary hidden for draft orders
- [ ] Currency formatting works correctly (NZD, USD, etc.)
- [ ] Line item totals calculate correctly (qty × unit cost)
- [ ] Discount and tax conditionally display
- [ ] All sections responsive and properly styled
