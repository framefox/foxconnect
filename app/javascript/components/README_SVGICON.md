# SvgIcon Component

A React component that mimics the Rails `svg_icon` helper functionality. It dynamically loads SVG files from the Rails asset pipeline (`app/assets/images/icons/`).

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

1. The component fetches the SVG file from the Rails `/icons/:name` endpoint at runtime
2. The `IconsController` serves the SVG from `app/assets/images/icons/`
3. The component processes the SVG content to:
   - Replace fill/stroke colors with `currentColor` (so it inherits text color)
   - Add your className
   - Add any additional HTML attributes
4. It renders the processed SVG inline

This matches the behavior of the Rails `svg_icon` helper!

## Setup

The following files were created to support this:
- `app/controllers/icons_controller.rb` - Serves SVG icons
- Route: `get "icons/:name"` - Maps to the controller

## Notes

- Icons are loaded asynchronously, so there may be a brief delay on first render
- Failed icon loads will log a warning in development mode
- The component returns `null` while loading or if the icon fails to load
- All SVG attributes use `currentColor` so they inherit the text color from parent elements

