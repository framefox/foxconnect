# Store Model Refactoring Summary

## Overview

Refactored the `Store` model from a Shopify-specific implementation to a platform-agnostic design that supports multiple e-commerce platforms (Shopify, Wix, Squarespace).

## What Was Done

### 1. Created Platform-Specific Concerns

#### `ShopifyIntegration`

- Moved all Shopify-specific methods from Store model
- Handles Shopify API sessions, product sync, admin URLs
- Includes GraphQL API integration for fetching shop data
- Validates Shopify-specific fields only when platform is "shopify"

#### `ShopifySessionStorage`

- Extracted ShopifyApp::ShopSessionStorage interface implementation
- Handles session storage/retrieval for Shopify App framework
- Keeps Shopify app integration separate from core Store logic

#### `WixIntegration` & `SquarespaceIntegration`

- Created placeholder concerns for future platform integrations
- Provides structure for adding Wix and Squarespace support
- Includes validation and URL generation patterns

### 2. Refactored Store Model

#### Before:

```ruby
class Store < ApplicationRecord
  include ShopifyApp::ShopSessionStorage

  # Mixed Shopify-specific and generic code
  def self.store(session)
    # Shopify session storage logic
  end

  def shopify_session
    # Shopify API logic
  end

  # etc...
end
```

#### After:

```ruby
class Store < ApplicationRecord
  include ShopifySessionStorage
  include ShopifyIntegration
  include WixIntegration
  include SquarespaceIntegration

  # Clean, platform-agnostic methods
  def sync_products!
    case platform
    when "shopify" then sync_shopify_products!
    when "wix" then sync_wix_products!
    when "squarespace" then sync_squarespace_products!
    end
  end
end
```

### 3. Database Schema Updates

#### Added Multi-Platform Support:

- Made `shopify_domain` optional (nullable)
- Added `wix_site_id`, `wix_token` columns
- Added `squarespace_domain`, `squarespace_token` columns
- Updated indexes to handle NULL values properly
- Extended platform enum to include "wix" and "squarespace"

### 4. Platform-Agnostic Methods

#### New Generic Methods:

- `platform_display_name()` - Human-readable platform name
- `platform_admin_url()` - Admin URL for any platform
- `connected?()` - Check if store has valid credentials
- `display_identifier()` - Platform-appropriate identifier
- `sync_products!()` - Delegates to platform-specific sync

## Benefits

### ✅ Separation of Concerns

- Each platform's logic is isolated in its own concern
- Core Store model focuses on business logic, not platform specifics
- Easy to test individual platform integrations

### ✅ Extensibility

- Adding new platforms requires only creating a new concern
- No modifications to core Store model needed
- Consistent patterns across all platform integrations

### ✅ Maintainability

- Shopify-specific code is contained and organized
- Platform-agnostic methods provide consistent interface
- Clear boundaries between different responsibilities

### ✅ Future-Proof

- Database schema ready for multiple platforms
- Code structure supports easy addition of Wix, Squarespace, etc.
- Validation logic handles platform-specific requirements

## Usage Examples

```ruby
# Shopify store
shopify_store = Store.find_by(platform: "shopify")
shopify_store.sync_products!  # Calls sync_shopify_products!
shopify_store.platform_admin_url  # Returns Shopify admin URL

# Future: Wix store
wix_store = Store.create!(
  name: "My Wix Store",
  platform: "wix",
  wix_site_id: "abc123",
  wix_token: "token123"
)
wix_store.sync_products!  # Will call sync_wix_products!
wix_store.connected?  # Checks wix_token presence
```

## Files Modified/Created

### Created:

- `app/models/concerns/shopify_integration.rb`
- `app/models/concerns/shopify_session_storage.rb`
- `app/models/concerns/wix_integration.rb`
- `app/models/concerns/squarespace_integration.rb`
- `db/migrate/20250928222517_update_stores_for_multi_platform.rb`

### Modified:

- `app/models/store.rb` - Completely refactored
- Database schema - Added multi-platform support

## Next Steps

1. **Implement Wix Integration**: Add actual Wix API calls to `WixIntegration`
2. **Implement Squarespace Integration**: Add actual Squarespace API calls to `SquarespaceIntegration`
3. **Add Platform-Specific Jobs**: Create `WixProductSyncJob`, `SquarespaceProductSyncJob`
4. **Extend Order Processing**: Add platform-specific order processing logic
5. **Add Platform-Specific Validations**: Enhance validation logic for each platform's requirements
