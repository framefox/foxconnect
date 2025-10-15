# Framefox Connect

A drop-shipping service platform for art businesses, connecting print/art sellers with e-commerce platforms starting with Shopify integration.

## Overview

Framefox Connect enables art businesses to:

- **Connect multiple Shopify stores** for centralized management
- **Sync products** from customer stores to internal catalog
- **Process orders** automatically when placed in connected stores
- **Manage fulfillment** for drop-shipping operations

## Tech Stack

- **Rails 8.0.3** - Web framework
- **PostgreSQL** - Primary database
- **Tailwind CSS v4** - Styling framework with shadcn/ui design system
- **Shopify App Gem** - Shopify integration and OAuth
- **Puma** - Application server

## Phase 1: Complete ✅

**Shopify Authentication & Store Management**

- [x] Shopify App integration with OAuth 2.0
- [x] Non-embedded app configuration
- [x] Store session management with database persistence
- [x] Admin dashboard for store management
- [x] Multi-platform database structure (ready for WooCommerce, Etsy, etc.)

## Quick Start

### Prerequisites

- Ruby 3.3.8+
- PostgreSQL 13+
- Node.js 18+ (for Shopify CLI)

### Installation

1. **Clone and setup:**

   ```bash
   git clone https://github.com/framefox/foxconnect.git
   cd foxconnect
   bundle install
   ```

2. **Database setup:**

   ```bash
   bin/rails db:create db:migrate
   ```

3. **Environment variables:**

   ```bash
   # Add to your .env file or environment
   export SHOPIFY_API_KEY="your_shopify_api_key"
   export SHOPIFY_API_SECRET="your_shopify_api_secret"
   ```

4. **Start development server:**

   ```bash
   bin/dev
   ```

5. **Access the application:**
   - Homepage: http://localhost:3000
   - Admin Dashboard: http://localhost:3000/admin
   - Connect Shopify: http://localhost:3000/login

## Shopify Integration

### Configuration

The app is configured as a **non-embedded Shopify app** with the following scopes:

- `read_products` - Read product data
- `read_orders` - Read order information
- `write_orders` - Create/update orders
- `read_locations` - Access store locations
- `read_fulfillments` - Track fulfillments
- `read_inventory` - Monitor inventory
- `read_customers` - Access customer data
- `write_draft_orders` - Create draft orders

### Authentication Flow

1. User visits `/admin` and clicks "Connect Shopify Store"
2. Redirected to Shopify OAuth authorization
3. After approval, store data is saved to `stores` table
4. User returns to admin dashboard with active connection

### Store Management

Connected stores are managed through the admin interface at `/admin/stores` with features:

- View all connected stores
- Sync products (Phase 2)
- Disconnect stores
- Monitor connection status

## Database Schema

### Stores Table

```ruby
# Primary table for managing e-commerce platform connections
create_table :stores do |t|
  t.string :name, null: false
  t.string :platform, null: false, default: 'shopify'
  t.string :shopify_domain, null: false
  t.string :shopify_token
  t.string :access_scopes
  t.json :settings, default: {}
  t.boolean :active, default: true
  t.datetime :last_sync_at
  t.timestamps
end
```

**Indexes:**

- `platform` - Fast platform filtering
- `shopify_domain` - Unique constraint for Shopify stores
- `[platform, active]` - Active stores by platform

## Development

### Running the Application

```bash
# Development server with Tailwind CSS watching
bin/dev

# Or run components separately
bin/rails server          # Rails app on :3000
bin/rails tailwindcss:watch[always]  # CSS compilation
```

### Tailwind CSS

This project uses [Tailwind CSS v4](https://github.com/rails/tailwindcss-rails) with the Rails integration. The watch command uses the `[always]` flag for reliable file watching in development.

**Styling Guide:** Follows shadcn/ui design patterns with slate color palette for consistent, accessible UI components.

### Admin Interface

The admin interface (`/admin/*`) uses:

- **Authentication**: ShopifyApp::LoginProtection
- **Layout**: Custom admin layout with navigation
- **Styling**: shadcn/ui inspired components with Tailwind CSS

## API Documentation

### Shopify App Configuration

Based on [Shopify App Gem documentation](https://github.com/Shopify/shopify_app):

```ruby
# config/initializers/shopify_app.rb
ShopifyApp.configure do |config|
  config.application_name = "Framefox Connect"
  config.embedded_app = false  # Non-embedded app
  config.api_version = "2025-10"
  config.shop_session_repository = "Store"
  config.new_embedded_auth_strategy = false
end
```

### Session Storage

Implements `ShopifyApp::ShopSessionStorage` interface for database-backed session management:

```ruby
# app/models/store.rb
class Store < ApplicationRecord
  include ShopifyApp::ShopSessionStorage

  def self.store(session)
    # Store Shopify session data
  end

  def self.retrieve(id)
    # Retrieve session for API calls
  end
end
```

## Roadmap

### Phase 2: Product Synchronization (Planned)

- [ ] Sync products from Shopify stores
- [ ] Map external products to internal catalog
- [ ] Product variant management
- [ ] Inventory tracking

### Phase 3: Order Processing (Planned)

- [ ] Webhook integration for real-time orders
- [ ] Automatic order creation in internal system
- [ ] Order status synchronization
- [ ] Fulfillment workflow

### Phase 4: Multi-Platform (Planned)

- [ ] WooCommerce integration
- [ ] Etsy marketplace support
- [ ] Custom API connectors

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Documentation Links

- [Shopify App Gem](https://github.com/Shopify/shopify_app) - Main integration library
- [Shopify API Documentation](https://shopify.dev/docs/api) - API reference
- [Tailwind CSS Rails](https://github.com/rails/tailwindcss-rails) - CSS framework integration
- [Rails 8 Guides](https://guides.rubyonrails.org/) - Framework documentation
- [shadcn/ui](https://ui.shadcn.com/) - UI component design system

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

For support with this application:

- Create an issue in this repository
- Contact: [your-email@framefox.com]

For Shopify-specific issues:

- [Shopify Community](https://community.shopify.com/)
- [Shopify App Development](https://shopify.dev/docs/apps)
