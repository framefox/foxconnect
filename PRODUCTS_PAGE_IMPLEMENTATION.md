# Products Page Implementation

## Overview
Created a new "Products" section in the sidebar navigation that allows users to browse available frame products without selecting them. This reuses the product selection modal code but presents it as a standalone page.

## Changes Made

### 1. React Component - `ProductBrowser.js`
**File:** `app/javascript/components/ProductBrowser.js`

Created a standalone React component that reuses most of the logic from `ProductSelectionStep.js`:
- **Type Selection View**: Grid of product types (matted, unmatted, canvas, print-only) and saved products button
- **Product Browser View**: Table view with filters for frame style, mat border, glass type, paper type, and print size
- **Saved Products View**: Table view of saved frame products

**Key Differences from ProductSelectionStep:**
- Removed the `onProductSelect` callback and "Select" button from table rows
- Added breadcrumb navigation with "Back to Product Selection" button
- Added page headers for better navigation
- Removed modal-specific props and behaviors

**Features Retained:**
- Same filtering and search functionality
- Star/save functionality for products
- Custom print size creation
- Collection filtering for frame styles
- Real-time search with external API
- Loading states and error handling

### 2. Rails Controller
**File:** `app/controllers/products_controller.rb`

Simple controller with just an `index` action. The React component handles all data fetching from the external Framefox API.

### 3. Routes
**File:** `config/routes.rb`

Added:
```ruby
resources :products, only: [ :index ]
```

### 4. View Template
**File:** `app/views/products/index.html.erb`

Created view that:
- Sets page title to "Products"
- Includes descriptive header
- Renders the `ProductBrowser` React component with product type images

### 5. Sidebar Navigation
**File:** `app/views/shared/_sidebar.html.erb`

Added new navigation item:
- Name: "Products"
- Path: `products_path`
- Icon: `ProductFilledIcon` (active), `ProductIcon` (inactive)
- Positioned between "Uploads" and "Help / FAQ"

### 6. Icon Registry
**File:** `app/javascript/utils/iconRegistry.js`

Added `ProductIcon` to the bundled icons for instant rendering without API calls.

## Usage

Users can now:
1. Click "Products" in the sidebar navigation
2. Browse the grid of product types (or go to saved products)
3. Click on a product type to view available frame SKUs
4. Filter products by frame style, mat border, glass type, paper type, and size
5. Star products to save them for later reference
6. Create custom print sizes
7. Navigate back to product type selection using the breadcrumb

## Technical Notes

- The component automatically mounts via the React mounting system (`react-mount.js`)
- Product type images are passed from Rails using the `asset_path` helper
- All API calls go to the external Framefox API configured in `FramefoxConfig`
- Saved items are persisted via the existing `SavedItemsController`
- Custom sizes are managed via the existing `CustomPrintSizesController`

## Files Created
1. `app/javascript/components/ProductBrowser.js` (1,221 lines)
2. `app/controllers/products_controller.rb`
3. `app/views/products/index.html.erb`

## Files Modified
1. `config/routes.rb` - Added products route
2. `app/views/shared/_sidebar.html.erb` - Added Products navigation item
3. `app/javascript/utils/iconRegistry.js` - Added ProductIcon to registry

