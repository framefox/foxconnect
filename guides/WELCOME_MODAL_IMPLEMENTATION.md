# Welcome Modal Implementation

## Summary

Implemented a welcome modal that appears when a new Shopify store is successfully connected via OAuth. The modal provides a guided onboarding experience with a "Start Product Sync" button to help users get started immediately.

## Features

- **Automatic Detection**: Detects when a store is newly created during OAuth flow
- **Welcome Modal**: Beautiful modal with success message and next steps
- **Quick Start**: "Start Product Sync" button to immediately sync products
- **Dismissable**: Users can choose to sync later if needed
- **Clean URLs**: Modal closes by removing URL parameter for clean navigation

## Files Modified

### 1. Store Model (`app/models/store.rb`)

**Changes:**

- Modified `Store.store` method to track newly created stores
- Stores `newly_created_store` flag in RequestStore
- Stores `current_store_uid` in RequestStore for redirect

```ruby
# Track if this is a new store
is_new_store = store.new_record?

# ... save store ...

# Store flags for callback controller
RequestStore[:newly_created_store] = is_new_store
RequestStore[:current_store_uid] = store.uid
```

### 2. Connections Dashboard Controller (`app/controllers/connections/dashboard_controller.rb`)

**Changes:**

- Added check for newly created stores in the `index` action
- Redirects to store show page with `welcome=true` parameter for new stores
- This intercepts users landing on `/connections` after OAuth callback

```ruby
def index
  # Check if user just completed OAuth for a new store
  is_new_store = RequestStore[:newly_created_store]
  store_uid = RequestStore[:current_store_uid]

  if is_new_store && store_uid.present?
    # Clean up RequestStore
    RequestStore.delete(:newly_created_store)
    RequestStore.delete(:current_store_uid)

    # Redirect to store show page with welcome modal
    redirect_to connections_store_path(store_uid, welcome: true) and return
  end

  # ... rest of dashboard logic
end
```

**Why the Dashboard Controller?**

- ShopifyApp engine handles OAuth callback internally and redirects to `config.root_url` (/connections)
- By checking for new stores in the dashboard controller, we intercept the redirect
- This approach doesn't require overriding ShopifyApp's internal callback logic

### 3. Store Show Page (`app/views/stores/show.html.erb`)

**Changes:**

- Added WelcomeModal React component at the bottom
- Conditionally renders when `welcome=true` parameter is present
- Only shown for non-admin users

```erb
<% unless is_admin %>
  <!-- Welcome Modal for New Store Connection -->
  <% if params[:welcome] == "true" %>
    <div
      data-react-component="WelcomeModal"
      data-react-props='<%= {
        isOpen: true,
        storeName: @store.name,
        storeUid: @store.uid
      }.to_json %>'
    ></div>
  <% end %>
<% end %>
```

## Files Created

### 1. WelcomeModal Component (`app/javascript/components/WelcomeModal.js`)

**Features:**

- Success icon with green checkmark
- Welcome message with store name
- 4-step getting started guide
- "Start Product Sync" button (redirects to sync endpoint)
- "I'll do this later" button (closes modal)
- ESC key support
- Click outside to close
- Removes URL parameter on close for clean navigation

**Props:**

- `isOpen` (boolean): Controls modal visibility
- `storeName` (string): Name of the connected store
- `storeUid` (string): UID of the store for routing

### 2. Component Registration (`app/javascript/components.js`)

**Changes:**

- Imported WelcomeModal component
- Added to components registry

```javascript
import WelcomeModal from "./components/WelcomeModal";

const components = {
  // ... other components
  WelcomeModal,
};
```

## User Flow

1. **User Authenticates**: User completes Shopify OAuth flow
2. **Store Created**: `Store.store` method creates new store record and sets RequestStore flags
3. **OAuth Redirect**: ShopifyApp engine redirects to `/connections` (dashboard)
4. **Dashboard Intercept**: Dashboard controller checks for new store flags
5. **Custom Redirect**: Dashboard redirects to store show page with `welcome=true`
6. **Modal Appears**: WelcomeModal displays with success message and onboarding steps
7. **User Action**: User can either:
   - Click "Start Product Sync" → Redirects to sync endpoint → Returns to store page with success notice
   - Click "I'll do this later" → Modal closes, URL parameter removed
   - Press ESC or click outside → Same as "I'll do this later"

## Benefits

- **Better UX**: Immediate feedback on successful connection
- **Guided Onboarding**: Clear next steps for new users
- **Reduced Friction**: One-click product sync initiation
- **Non-Intrusive**: Easy to dismiss if user wants to explore first
- **Clean Navigation**: URL parameters cleaned up after modal closes

## Technical Details

### RequestStore Usage

Uses RequestStore (thread-safe, request-scoped storage) to pass data from the Store model to the controller:

- `RequestStore[:newly_created_store]` - Boolean flag
- `RequestStore[:current_store_uid]` - Store UID for redirect

This avoids modifying the ShopifyApp gem's internal behavior while still customizing the redirect flow.

### Modal State Management

The modal uses URL parameters to manage state:

- Appears when `?welcome=true` is in the URL
- Removes parameter on close using `window.history.replaceState`
- Prevents modal from reappearing on page refresh after closing

## Testing

To test the welcome modal:

1. Ensure you're logged in to the application
2. Navigate to `/connections`
3. Click "Connect Shopify" (or equivalent button)
4. Complete Shopify OAuth flow with a NEW store (not previously connected)
5. Verify:
   - Redirected to store show page (`/connections/stores/{uid}?welcome=true`)
   - Welcome modal appears automatically
   - Store name is displayed correctly
   - "Start Product Sync" button works
   - Modal closes properly and removes URL parameter
   - Clicking "I'll do this later" closes without syncing

## Future Enhancements

Possible improvements:

- Add analytics tracking for modal interactions
- Include video tutorial link in modal
- Add tooltips for each onboarding step
- Implement progressive disclosure for advanced features
- Add "Don't show this again" option with user preference storage
