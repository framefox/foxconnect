# Custom SVG Icons

This directory contains custom SVG icons that can be used throughout the application.

## Usage

To use an icon in your views:

```erb
<%= svg_icon('icon-name', class: 'w-5 h-5 text-slate-600') %>
```

## Adding New Icons

1. Save your SVG file in this directory with a descriptive kebab-case name (e.g., `order-unfulfilled-icon.svg`, `box.svg`, `truck.svg`)
2. Make sure the SVG has a `viewBox` attribute for proper scaling
3. Remove any hardcoded `width` and `height` attributes (use Tailwind classes instead)
4. Use `currentColor` for fills/strokes so the icon inherits text color

## Example SVG Format

```svg
<svg viewBox="0 0 24 24" fill="none" stroke="currentColor">
  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
</svg>
```

## Tips

- Keep icon files small and optimized
- Use consistent viewBox dimensions (typically 24x24 or 16x16)
- Remove unnecessary metadata and comments from exported SVGs
- Test icons with different color classes to ensure `currentColor` works properly

## Available Options

The `svg_icon` helper accepts these options:

- `class` - CSS classes to apply (e.g., 'w-5 h-5 text-blue-500')
- Any other HTML attribute (e.g., `aria_label`, `role`, etc.)

## Examples

```erb
<!-- Basic usage -->
<%= svg_icon('box', class: 'w-5 h-5') %>

<!-- With color -->
<%= svg_icon('truck', class: 'w-6 h-6 text-blue-600') %>

<!-- With accessibility -->
<%= svg_icon('alert', class: 'w-4 h-4', role: 'img', aria_label: 'Warning') %>

<!-- In a button -->
<button class="btn">
  <%= svg_icon('arrow-right', class: 'w-4 h-4 ml-2') %>
  Next
</button>
```

