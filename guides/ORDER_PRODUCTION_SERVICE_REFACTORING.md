# Order Production Service Refactoring

## Overview

The `OrderProductionService` has been successfully refactored from a monolithic 779-line class into a clean, modular architecture consisting of 5 focused services coordinated by a lightweight orchestrator.

## Why This Refactoring?

**Before**: A single 779-line service handling:

- HTTP communication with production API
- Shopify GraphQL interactions
- Draft order creation and updates
- Shipping rate fetching and application
- Production cost extraction and storage
- B2B customer data management

**After**: Six focused services with single responsibilities, making the codebase more maintainable, testable, and ready for future payment service integration.

## New Architecture

### 1. `OrderProductionService` (Orchestrator)

**Location**: `app/services/order_production_service.rb`  
**Lines**: 57 (reduced from 779)  
**Responsibility**: Lightweight orchestrator that coordinates the production workflow

**Key Methods**:

- `call` - Main entry point that orchestrates the three-step process:
  1. Send order to production API
  2. Save metadata and get draft order ID
  3. Complete draft order in Shopify

**Usage** (unchanged):

```ruby
service = OrderProductionService.new(order: @order)
result = service.call
# Returns: { success: true/false, response: data, error: message }
```

### 2. `Production::ApiClient`

**Location**: `app/services/production/api_client.rb`  
**Responsibility**: Communication with the FrameFox production API

**Key Methods**:

- `send_draft_order` - Sends order payload to production API
- `build_payload` - Constructs draft order items from order
- `api_url` - Builds country-specific API URL
- `handle_response` - Parses and handles API responses

**Features**:

- HTTP timeout handling (10s connect, 30s read)
- Comprehensive error message extraction
- Country-specific API endpoint support

### 3. `Production::CostService`

**Location**: `app/services/production/cost_service.rb`  
**Responsibility**: Extracting and saving production costs from API and Shopify responses

**Key Methods**:

- `save_draft_order_metadata(api_response)` - Saves draft order ID, timestamps, dispatch date
- `save_order_costs(shopify_order_data)` - Saves subtotal, shipping, total costs
- `save_line_item_costs(line_items_data)` - Matches and saves per-item costs
- `extract_money_amount(price_set)` - Helper for money extraction

**Data Saved**:

- `shopify_remote_draft_order_id`
- `in_production_at`
- `target_dispatch_date`
- `shopify_remote_order_id`
- `shopify_remote_order_name`
- `production_subtotal_cents`, `production_shipping_cents`, `production_total_cents`
- Line item: `shopify_remote_line_item_id`, `production_cost_cents`

### 4. `Shopify::GraphqlClient`

**Location**: `app/services/shopify/graphql_client.rb`  
**Responsibility**: Shared GraphQL client with country-specific credentials

**Key Methods**:

- `query(query_string, variables)` - Executes GraphQL requests
- `build_gid(resource_type, id)` - Utility for GID formatting

**Features**:

- Country-specific Shopify store selection
- Automatic session management
- Error logging with credential diagnostics

### 5. `Shopify::DraftOrderService`

**Location**: `app/services/shopify/draft_order_service.rb`  
**Responsibility**: Creating and updating Shopify draft orders with customer/B2B info

**Key Methods**:

- `complete` - Orchestrates update + shipping + finalize
- `update_customer` - Updates draft order with customer/company data
- `finalize` - Completes draft order, creates Shopify order
- `build_customer_input` - Builds B2B purchasing entity and address data

**B2B Features**:

- Handles company purchasing entities
- Manages company location and contact associations
- Applies "framefox-connect" tags

### 6. `Shopify::DraftOrderShippingService`

**Location**: `app/services/shopify/draft_order_shipping_service.rb`  
**Responsibility**: Fetching and applying shipping rates to draft orders

**Key Methods**:

- `apply_shipping` - Orchestrates fetch + select + apply
- `fetch_draft_order` - Gets draft order details
- `fetch_available_rates` - Queries available shipping rates
- `apply_rate` - Updates draft order with shipping line

**Features**:

- Comprehensive logging with visual separators
- Graceful handling of missing shipping zones
- Validation of draft order status and address

## Workflow

```
OrderProductionService.call
  │
  ├─► Production::ApiClient.send_draft_order
  │     └─► Sends payload to production API
  │     └─► Returns { success: true, response: {...} }
  │
  ├─► Production::CostService.save_draft_order_metadata
  │     └─► Saves draft order ID and timestamps
  │     └─► Logs production activity
  │     └─► Returns draft_order_gid
  │
  └─► Shopify::DraftOrderService.complete
        ├─► update_customer (using GraphqlClient)
        │     └─► Adds B2B purchasing entity
        │     └─► Adds shipping/billing addresses
        │
        ├─► DraftOrderShippingService.apply_shipping (using GraphqlClient)
        │     ├─► fetch_draft_order
        │     ├─► fetch_available_rates
        │     └─► apply_rate
        │
        └─► finalize (using GraphqlClient)
              └─► Completes draft order
              └─► Production::CostService saves order & line item costs
```

## Key Benefits

### 1. Single Responsibility Principle

Each service has one clear purpose, making code easier to understand and maintain.

### 2. Improved Testability

Services can be unit tested independently with mocked dependencies.

```ruby
# Example: Test Production::ApiClient without Shopify
RSpec.describe Production::ApiClient do
  it "sends draft order to production API" do
    # No need to mock Shopify GraphQL calls
  end
end
```

### 3. Reusability

Services can be used independently in other contexts.

```ruby
# Example: Use shipping service elsewhere
shipping_service = Shopify::DraftOrderShippingService.new(
  order: order,
  draft_order_gid: gid
)
shipping_service.apply_shipping
```

### 4. Easier Debugging

Smaller, focused services make it easier to locate and fix issues.

### 5. Future-Proof Architecture

Ready for payment service integration without bloating the orchestrator.

## Adding Payment Service (Future)

When you're ready to add payment processing, the architecture makes this straightforward:

### Step 1: Create Payment Service

```ruby
# app/services/payment/processor_service.rb
module Payment
  class ProcessorService
    def initialize(order:)
      @order = order
    end

    def process_payment
      # Payment logic here
      { success: true, transaction_id: "..." }
    end
  end
end
```

### Step 2: Update Orchestrator

```ruby
# app/services/order_production_service.rb
def call
  # ... existing steps 1-2 ...

  # Step 3: Process payment
  payment_result = Payment::ProcessorService.new(order: order).process_payment
  return failure("Payment failed: #{payment_result[:error]}") unless payment_result[:success]

  # Step 4: Complete draft order (existing step 3)
  complete_draft_order(draft_order_gid)

  api_result
end
```

### Step 3: Update DraftOrderService

Modify the `finalize` method to mark payment as completed:

```ruby
variables = {
  id: draft_order_gid,
  paymentPending: false  # Changed from true after payment processed
}
```

## Testing the Refactoring

The refactoring maintains backward compatibility. The public interface of `OrderProductionService` remains unchanged:

```ruby
# Controllers still work exactly the same
service = OrderProductionService.new(order: @order)
production_result = service.call

if production_result[:success]
  @order.submit!
  # ...
else
  # Handle error
end
```

### Manual Testing Checklist

- [ ] Order submission from regular user controller
- [ ] Order submission from admin controller
- [ ] Draft order creation in Shopify
- [ ] B2B purchasing entity application
- [ ] Shipping rate fetching and application
- [ ] Draft order completion
- [ ] Production cost saving
- [ ] Line item cost matching
- [ ] Order activity logging
- [ ] Error handling at each step

## File Structure

```
app/services/
├── order_production_service.rb          # Orchestrator (57 lines)
├── production/
│   ├── api_client.rb                   # Production API client (126 lines)
│   └── cost_service.rb                 # Cost extraction (139 lines)
└── shopify/
    ├── graphql_client.rb               # Shared GraphQL client (42 lines)
    ├── draft_order_service.rb          # Draft order management (243 lines)
    └── draft_order_shipping_service.rb # Shipping rates (339 lines)
```

**Total Lines**: ~946 lines (vs 779 in monolithic version)  
**Additional Lines**: ~167 lines for improved modularity, error handling, and documentation

The slight increase in total lines is offset by:

- Clearer separation of concerns
- Better error handling
- More comprehensive logging
- Improved maintainability
- Easier testing

## Migration Notes

- **No database changes required**
- **No API changes** - the public interface remains the same
- **No controller changes** - existing code works without modification
- **Backward compatible** - can be deployed without coordinating changes

## Common Issues & Solutions

### Issue: "uninitialized constant Production::ApiClient"

**Solution**: Restart Rails server to reload autoload paths for new `production/` and `shopify/` modules.

### Issue: GraphQL authentication errors

**Solution**: Check that country_config has correct `shopify_domain` and `shopify_access_token` for the order's country.

### Issue: No shipping rates returned

**Solution**: Verify:

1. Shipping zones configured for destination country
2. Products have weight/dimensions
3. Shopify API version supports `draftOrderAvailableDeliveryOptions`

## Conclusion

This refactoring transforms a complex monolithic service into a clean, modular architecture that's easier to understand, test, and extend. The orchestrator pattern keeps the high-level workflow clear while delegating specific responsibilities to focused services.

The architecture is now ready for payment service integration and other future enhancements without becoming unwieldy.
