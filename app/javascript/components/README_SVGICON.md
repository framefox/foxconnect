# SvgIcon Component

A React component that mimics the Rails `svg_icon` helper functionality. Commonly used icons (~35) are bundled in JavaScript for instant rendering with zero network requests. Uncommon icons fall back to loading from the Rails asset pipeline.

## Usage

### Basic Usage

```jsx
import { SvgIcon } from "../components";

function MyComponent() {
  return (
    <div>
      <SvgIcon name="OrderFulfilledIcon" className="w-5 h-5" />
    </div>
  );
}
```

### With Tailwind Classes

```jsx
<SvgIcon name="XCircleIcon" className="w-4 h-4 text-red-600" />
<SvgIcon name="PackageFulfilledIcon" className="w-6 h-6 text-blue-500" />
```

### With Accessibility Attributes

```jsx
<SvgIcon 
  name="AlertCircleIcon" 
  className="w-5 h-5" 
  role="img" 
  aria-label="Warning"
/>
```

### In Buttons and Links

```jsx
<button className="flex items-center space-x-2">
  <SvgIcon name="OrderFulfilledIcon" className="w-4 h-4" />
  <span>Mark as Fulfilled</span>
</button>
```

## Props

| Prop | Type | Required | Description |
|------|------|----------|-------------|
| `name` | string | Yes | The name of the SVG file (without `.svg` extension) |
| `className` | string | No | CSS classes to apply to the SVG (Tailwind classes work great) |
| `...otherProps` | any | No | Any other HTML attributes (aria-label, role, etc.) in camelCase |

## Examples from ERB to React

### ERB Version
```erb
<%= svg_icon('OrderFulfilledIcon', class: 'w-5 h-5 text-green-600') %>
```

### React Version
```jsx
<SvgIcon name="OrderFulfilledIcon" className="w-5 h-5 text-green-600" />
```

---

### ERB Badge with Icon
```erb
<span class="inline-flex items-center rounded-lg bg-green-100 px-2 py-1 text-xs font-medium text-green-800">
  <%= svg_icon("OrderFulfilledIcon", class: "w-4 h-4 mr-1") %>
  Fulfilled
</span>
```

### React Badge with Icon
```jsx
<span className="inline-flex items-center rounded-lg bg-green-100 px-2 py-1 text-xs font-medium text-green-800">
  <SvgIcon name="OrderFulfilledIcon" className="w-4 h-4 mr-1" />
  Fulfilled
</span>
```

## Performance

**Bundled Icons (Instant Rendering):**
Commonly used icons are bundled with JavaScript and render instantly without network requests:
- StarFilledIcon, StarIcon, UploadIcon, SearchIcon, DeleteIcon, ViewIcon, ReplaceIcon, PlusCircleIcon
- ImageMagicIcon, CheckIcon, AlertCircleIcon, AlertTriangleIcon, XIcon, RefreshIcon, ThumbsUpIcon
- SaveIcon, ImageIcon, ProductFilledIcon, OrderFilledIcon, DeliveryFilledIcon, ExternalSmallIcon
- StatusActiveIcon, ProductReferenceIcon, SearchResourceIcon, CheckCircleIcon, XCircleIcon
- MinusIcon, ChevronDownIcon, ChevronUpIcon, ChevronLeftIcon, ChevronRightIcon, InfoIcon

**On-Demand Icons (Fetched):**
All other SVG files in `app/assets/images/icons/` are available and will be fetched from the server when needed.

## Available Icons

All SVG files in `app/assets/images/icons/` are available. Some commonly used icons:

- `OrderFulfilledIcon`
- `OrderDraftIcon`
- `PackageFulfilledIcon`
- `XCircleIcon`
- `AlertCircleIcon`
- `ProductFilledIcon`
- `WifiIcon`
- `HeartIcon`
- And many more...

See the `/app/assets/images/icons/` directory for all available icons.

## How It Works

**For Bundled Icons (Most Common):**
1. Icon SVG is imported directly into the JavaScript bundle at build time
2. Component looks up the icon in the registry (instant, synchronous)
3. Processes the SVG to add className and attributes
4. Renders immediately with zero network requests

**For On-Demand Icons (Uncommon):**
1. Component fetches the SVG from the Rails `/icons/:name` endpoint
2. `IconsController` serves the SVG from `app/assets/images/icons/`
3. Processes and renders the SVG

This matches the behavior of the Rails `svg_icon` helper!

## Setup

The following files were created to support this:
- `app/controllers/icons_controller.rb` - Serves SVG icons
- Route: `get "icons/:name"` - Maps to the controller

## Notes

- **Bundled icons** render instantly with no loading delay
- **On-demand icons** are loaded asynchronously and may have a brief delay on first render
- Failed icon loads will log a warning in development mode
- The component returns `null` while loading (on-demand only) or if the icon fails to load
- All SVG attributes use `currentColor` so they inherit the text color from parent elements
- To add more icons to the bundle, edit `app/javascript/utils/iconRegistry.js`

