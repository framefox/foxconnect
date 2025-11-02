# SvgIcon Setup - Bundled Icons

## 🚀 Performance Upgrade

The SvgIcon component now uses a **hybrid approach** for optimal performance:

1. **Bundled Icons** (~35 commonly used icons): Loaded instantly with zero network requests
2. **On-Demand Icons** (all others): Fetched from server when needed

## What's Included

### 1. Icon Registry
**File:** `app/javascript/utils/iconRegistry.js`
- Bundles ~35 commonly used SVG icons
- Icons are processed at build time
- Zero runtime overhead for common icons

### 2. React Component (Updated)
**File:** `app/javascript/components/SvgIcon.js`
- Checks bundled registry first (instant rendering)
- Falls back to API fetch for uncommon icons
- No loading states for bundled icons
- Exported in `app/javascript/components.js`

### 3. Fallback Controller (Still Available)
**File:** `app/controllers/icons_controller.rb`
- Serves SVG files from `app/assets/images/icons/`
- Endpoint: `GET /icons/:name`
- Used for icons not in the bundle

### 4. Route
**File:** `config/routes.rb`
```ruby
get "icons/:name", to: "icons#show", constraints: { name: /[^\/]+/ }
```

## Testing

After restarting the server, test the endpoint:

```bash
curl http://localhost:3000/icons/ExternalSmallIcon
```

You should see SVG content, not HTML.

## Usage in React

```jsx
import { SvgIcon } from "../components";

<SvgIcon name="ExternalSmallIcon" className="w-4 h-4" />
```

## Troubleshooting

### 404 Error
- **Cause:** Server not restarted or icon doesn't exist
- **Fix:** Restart server, check icon name

### Icon Not Displaying
- **Cause:** Typo in icon name
- **Fix:** Check `app/assets/images/icons/` for correct name (without `.svg`)

### List Available Icons
```bash
ls app/assets/images/icons/
```

