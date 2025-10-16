# SvgIcon Setup - Important Note

## ⚠️ Server Restart Required

After setting up the SvgIcon component, you **must restart your Rails server** for the new route to take effect.

```bash
# Stop your Rails server (Ctrl+C)
# Then restart it:
rails s
# or
bin/dev
```

## What Was Added

### 1. Controller
**File:** `app/controllers/icons_controller.rb`
- Serves SVG files from `app/assets/images/icons/`
- Endpoint: `GET /icons/:name`

### 2. Route
**File:** `config/routes.rb`
```ruby
get "icons/:name", to: "icons#show", constraints: { name: /[^\/]+/ }
```

### 3. React Component
**File:** `app/javascript/components/SvgIcon.js`
- Fetches icons from `/icons/:name`
- Processes SVG to add `currentColor` and classes
- Exported in `app/javascript/components.js`

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

