# SvgIcon Quick Reference

## Import

```jsx
import { SvgIcon } from "../components";
```

## Basic Usage

```jsx
// Simple icon
<SvgIcon name="OrderFulfilledIcon" className="w-5 h-5" />

// Icon with color
<SvgIcon name="XCircleIcon" className="w-4 h-4 text-red-600" />

// Icon with accessibility
<SvgIcon name="AlertCircleIcon" className="w-5 h-5" aria-label="Warning" />
```

## Common Patterns

### In Badges

```jsx
<span className="inline-flex items-center rounded-lg bg-green-100 px-2 py-1">
  <SvgIcon name="OrderFulfilledIcon" className="w-4 h-4 mr-1" />
  Fulfilled
</span>
```

### In Buttons

```jsx
<button className="flex items-center space-x-2">
  <SvgIcon name="PackageFulfilledIcon" className="w-5 h-5" />
  <span>Ship Order</span>
</button>
```

### Conditional Icons

```jsx
{isActive ? (
  <SvgIcon name="OrderFulfilledIcon" className="w-5 h-5 text-green-600" />
) : (
  <SvgIcon name="OrderDraftIcon" className="w-5 h-5 text-slate-400" />
)}
```

## ERB Equivalent

```erb
<!-- ERB -->
<%= svg_icon('OrderFulfilledIcon', class: 'w-5 h-5 text-green-600') %>
```

```jsx
{/* React */}
<SvgIcon name="OrderFulfilledIcon" className="w-5 h-5 text-green-600" />
```

## Available Props

- `name` (required): Icon filename without `.svg`
- `className`: Tailwind/CSS classes
- Any HTML attribute in camelCase: `ariaLabel`, `role`, etc.

## Tips

- All icons inherit text color via `currentColor`
- Use Tailwind text color classes: `text-blue-600`, `text-red-500`, etc.
- Icons are in `/app/assets/images/icons/`
- Common icons (~35) are bundled for instant rendering
- Uncommon icons are fetched on-demand (may show brief loading state)

## Finding Icons

```bash
# List all available icons
ls app/assets/images/icons/
```

