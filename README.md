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
- **React 19** - UI components (via esbuild bundling)
- **esbuild** - JavaScript bundler (via jsbundling-rails)
- **Propshaft** - Asset pipeline
- **Shopify App Gem** - Shopify integration and OAuth
- **Puma** - Application server
- **Sidekiq** - Background job processing

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
   npm install
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

## JavaScript & React Architecture

This project uses a hybrid approach combining Rails with React components bundled via esbuild. This allows you to use React for interactive components while keeping the simplicity of Rails server-rendered views.

### Core Technologies

| Technology | Purpose |
|------------|---------|
| **esbuild** | JavaScript bundler (fast builds, JSX support) |
| **jsbundling-rails** | Rails integration for esbuild |
| **Propshaft** | Modern Rails asset pipeline |
| **React 19** | UI component library |
| **ES Modules** | Module format (`type: "module"` in script tags) |

### How It Works

1. **esbuild bundles** `app/javascript/application.js` → `app/assets/builds/application.js`
2. **Propshaft serves** assets from `app/assets/builds/` with fingerprinting
3. **Rails layouts** include the bundle with `javascript_include_tag "application", type: "module"`
4. **React components mount** automatically via `data-react-component` attributes in ERB

### Directory Structure

```
app/
├── javascript/
│   ├── application.js        # Entry point - imports all modules
│   ├── react-mount.js        # Auto-mounts React components from DOM
│   ├── components.js         # Component registry (alternative mounting)
│   ├── components/           # React components
│   │   ├── HelloReact.js     # Example component
│   │   ├── Uploader.jsx      # File uploader (JSX extension)
│   │   ├── ProductBrowser.js # Product selection
│   │   └── ...
│   └── utils/                # Utility modules
│       ├── sentry.js         # Error tracking
│       ├── iconRegistry.js   # Bundled SVG icons
│       └── ...
├── assets/
│   ├── builds/               # Compiled JS output (gitignored)
│   │   └── application.js    # esbuild output
│   ├── config/
│   │   └── manifest.js       # Propshaft manifest
│   ├── stylesheets/
│   │   └── application.css   # Main CSS (imports Tailwind)
│   └── images/
│       └── icons/            # SVG icon library
└── views/
    └── layouts/
        └── application.html.erb  # Includes JS bundle
```

### esbuild Configuration

The `esbuild.config.js` file configures JavaScript bundling:

```javascript
const config = {
  entryPoints: ["app/javascript/application.js"],
  outdir: "app/assets/builds",
  bundle: true,
  format: "esm",           // ES Modules output
  sourcemap: true,         // Source maps for debugging
  publicPath: "/assets",   // Asset URL prefix
  jsx: "transform",        // Enable JSX
  jsxFactory: "React.createElement",
  jsxFragment: "React.Fragment",
  loader: {
    ".js": "jsx",          // Treat .js files as JSX
    ".svg": "text",        // Import SVGs as text strings
  },
  define: {
    "process.env.NODE_ENV": '"development"',
  },
};
```

**Key features:**
- `.js` files can contain JSX (no `.jsx` extension required)
- SVG files can be imported as text for inline rendering
- Source maps enabled for debugging
- ES Modules format for modern browser support

### package.json Dependencies

```json
{
  "dependencies": {
    "react": "19",
    "react-dom": "19",
    "axios": "^1.6.0",           // HTTP client
    "classnames": "^2.5.1",       // Conditional CSS classes
    "react-modal": "^3.16.3",     // Modal dialogs
    "react-easy-crop": "^5.5.2",  // Image cropping
    "react-device-detect": "^2.2.3", // Device detection
    "@sentry/browser": "^8.55.0", // Error tracking
    "esbuild": "^0.19.0"          // Bundler (runtime dep)
  },
  "scripts": {
    "build": "node esbuild.config.js",
    "build:watch": "node esbuild.config.js --watch"
  },
  "engines": {
    "node": ">=18.0.0"
  }
}
```

### React Component Mounting System

Components are mounted automatically using `data-react-component` attributes in ERB templates.

#### In ERB Templates

```erb
<%# Mount a React component with props %>
<div 
  data-react-component="ProductBrowser" 
  data-react-props='<%= { products: @products, categories: @categories }.to_json %>'>
</div>

<%# Simple component without props %>
<div data-react-component="HelloReact"></div>
```

#### The Mounting Script (react-mount.js)

```javascript
document.addEventListener("DOMContentLoaded", () => {
  const targets = document.querySelectorAll("[data-react-component]");
  targets.forEach(async (el) => {
    const componentName = el.dataset.reactComponent;
    const props = parseProps(el.getAttribute("data-react-props"));
    
    // Dynamic import from components folder
    const module = await import(`./components/${componentName}.js`);
    const Component = module.default;
    const root = createRoot(el);
    root.render(React.createElement(Component, props));
  });
});
```

**Mounting behavior:**
- Components are dynamically imported (code splitting potential)
- Props are parsed from JSON in `data-react-props` attribute
- Uses React 18+ `createRoot` API
- Handles HTML entity encoding in props

### Creating a New React Component

1. **Create the component file** in `app/javascript/components/`:

```javascript
// app/javascript/components/MyComponent.js
import React, { useState } from "react";

function MyComponent({ title, items = [] }) {
  const [selected, setSelected] = useState(null);

  return (
    <div className="p-4 bg-white rounded-lg shadow">
      <h2 className="text-xl font-semibold">{title}</h2>
      <ul className="mt-4 space-y-2">
        {items.map((item, i) => (
          <li 
            key={i}
            onClick={() => setSelected(i)}
            className={selected === i ? "bg-blue-100" : ""}
          >
            {item.name}
          </li>
        ))}
      </ul>
    </div>
  );
}

export default MyComponent;
```

2. **Use in ERB template**:

```erb
<div 
  data-react-component="MyComponent" 
  data-react-props='<%= { title: "My Items", items: @items }.to_json %>'>
</div>
```

3. **That's it!** The component will be auto-mounted on page load.

### SVG Icon System

The project includes a React-compatible SVG icon system that works with both JavaScript and Rails views.

#### In React Components

```javascript
import SvgIcon from "./SvgIcon";

// Use any icon by name (matches filename in app/assets/images/icons/)
<SvgIcon name="CheckIcon" className="w-5 h-5 text-green-600" />
<SvgIcon name="AlertCircleIcon" className="w-4 h-4 text-red-500" />
```

#### Icon Registry

Common icons are pre-bundled in `app/javascript/utils/iconRegistry.js` for instant rendering:

```javascript
// Icons are imported as text and processed at build time
import CheckIcon from "../../assets/images/icons/CheckIcon.svg";

export const iconRegistry = {
  CheckIcon: processSvgForRegistry(CheckIcon),
  // ... more icons
};
```

**Benefits:**
- Bundled icons render instantly (no network request)
- Fallback to API fetch for non-bundled icons
- SVGs inherit text color via `currentColor`

### Asset Pipeline (Propshaft)

The `app/assets/config/manifest.js` defines which assets are served:

```javascript
//= link_tree ../images
//= link_directory ../stylesheets .css
//= link_tree ../builds          // Compiled JS from esbuild
//= link application.js
//= link tailwind.css
```

**How assets flow:**
1. esbuild compiles JS to `app/assets/builds/`
2. Tailwind CSS compiles to `app/assets/builds/tailwind.css`
3. Propshaft fingerprints and serves from `app/assets/`

### Development Workflow

The `Procfile.dev` runs all development processes:

```bash
web: kill -9 $(lsof -ti:3000) 2>/dev/null || true && bin/rails server -p 3000 -b 0.0.0.0
css: bin/rails tailwindcss:watch[always]
js: npm run build:watch
```

**Start development:**
```bash
bin/dev
```

This runs:
1. **Rails server** on port 3000
2. **Tailwind CSS watcher** for real-time CSS compilation
3. **esbuild watcher** for JavaScript hot reloading

### Production Build

For production, assets are compiled during deployment:

```bash
# Compile JavaScript
npm run build

# Compile Tailwind CSS
bin/rails tailwindcss:build

# Precompile all assets (Propshaft)
bin/rails assets:precompile
```

### Layout Integration

Layouts include JavaScript and CSS:

```erb
<%# app/views/layouts/application.html.erb %>
<head>
  <%= stylesheet_link_tag "tailwind" %>
  <%= javascript_include_tag "application", type: "module" %>
</head>
```

**Key points:**
- `type: "module"` enables ES Module syntax
- Tailwind CSS is loaded as a separate stylesheet
- No importmap needed (esbuild bundles everything)

### Gemfile Dependencies for JS/CSS

```ruby
# Asset pipeline
gem "propshaft"           # Modern asset pipeline

# JavaScript
gem "jsbundling-rails"    # esbuild integration
gem "stimulus-rails"      # Hotwire Stimulus (optional)

# CSS
gem "tailwindcss-rails"   # Tailwind CSS integration
```

### Adding New npm Packages

```bash
# Add a new dependency
npm install package-name

# Import in your component
import something from "package-name";
```

esbuild will bundle the package into your JavaScript build.

### Common Patterns

#### Passing Rails Data to React

```erb
<%# Simple props %>
<div data-react-component="UserCard" 
     data-react-props='<%= { user: @user.as_json }.to_json %>'>
</div>

<%# Complex nested data %>
<div data-react-component="Dashboard" 
     data-react-props='<%= {
       orders: @orders.map { |o| { id: o.id, status: o.status } },
       stats: { total: @total, pending: @pending }
     }.to_json %>'>
</div>
```

#### Making API Calls from React

```javascript
import axios from "axios";

// Get CSRF token from Rails
const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content;

// Make authenticated request
const response = await axios.post("/api/endpoint", data, {
  headers: { "X-CSRF-Token": csrfToken }
});
```

#### Global Configuration

Pass global config via window object:

```erb
<script>
  window.FramefoxConfig = {
    apiAuthToken: "<%= @api_token %>",
    currentUserId: <%= current_user&.id || "null" %>
  };
</script>
```

Access in React:

```javascript
const apiToken = window.FramefoxConfig?.apiAuthToken;
```

### Debugging Tips

1. **Check browser console** for React mounting errors
2. **View source maps** in browser DevTools for original code
3. **Check esbuild output** in terminal for build errors
4. **Verify asset paths** with `bin/rails assets:reveal`

### Migrating This Setup to a New App

To replicate this JavaScript/React setup in a new Rails app:

1. **Create Rails app with esbuild:**
   ```bash
   rails new myapp -j esbuild -c tailwind --database=postgresql
   ```

2. **Install React:**
   ```bash
   npm install react react-dom
   ```

3. **Configure esbuild** - copy `esbuild.config.js` to enable JSX

4. **Create mounting system** - copy `app/javascript/react-mount.js`

5. **Update Procfile.dev** - ensure JS watcher is included

6. **Create components directory** - `app/javascript/components/`

7. **Add to layout:**
   ```erb
   <%= javascript_include_tag "application", type: "module" %>
   ```

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

## Troubleshooting

### Common JavaScript/React Issues

**Component not mounting:**
- Check browser console for errors
- Verify component name matches filename exactly (case-sensitive)
- Ensure the component has a `default` export
- Check that `data-react-props` is valid JSON

**esbuild build fails:**
```bash
# Clear node_modules and reinstall
rm -rf node_modules
npm install
npm run build
```

**Assets not updating in development:**
```bash
# Restart all processes
bin/dev

# Or manually rebuild
npm run build
bin/rails tailwindcss:build
```

**"Module not found" errors:**
- Verify package is in `package.json` dependencies
- Run `npm install` after adding dependencies
- Check import path is correct (relative vs package)

**JSX syntax errors:**
- Ensure `esbuild.config.js` has `loader: { ".js": "jsx" }`
- Verify file is being processed by esbuild (in entry point tree)

### Asset Pipeline Issues

**Missing assets in production:**
```bash
# Precompile assets
RAILS_ENV=production bin/rails assets:precompile

# Check what's being served
bin/rails assets:reveal
```

**Fingerprinting issues:**
- Propshaft auto-fingerprints; don't manually add hashes
- Use `asset_path()` helper for dynamic asset URLs

### React Component Debugging

**Add debug logging to mounting:**
```javascript
// In react-mount.js, logging is already enabled
console.debug(`Mounting ${componentName} with props`, props);
```

**Inspect mounted components:**
```javascript
// In browser console
document.querySelectorAll('[data-react-component]')
```

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## Documentation Links

### Rails & Backend
- [Rails 8 Guides](https://guides.rubyonrails.org/) - Framework documentation
- [Shopify App Gem](https://github.com/Shopify/shopify_app) - Main integration library
- [Shopify API Documentation](https://shopify.dev/docs/api) - API reference

### JavaScript & React
- [jsbundling-rails](https://github.com/rails/jsbundling-rails) - Rails esbuild integration
- [esbuild](https://esbuild.github.io/) - JavaScript bundler documentation
- [React 19 Documentation](https://react.dev/) - React official docs
- [Propshaft](https://github.com/rails/propshaft) - Modern Rails asset pipeline

### CSS & Styling
- [Tailwind CSS Rails](https://github.com/rails/tailwindcss-rails) - CSS framework integration
- [Tailwind CSS v4](https://tailwindcss.com/docs) - Utility-first CSS framework
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
