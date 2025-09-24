---
description: Apply this styling when dealing with UI
alwaysApply: true
---

# shadcn/ui Admin Styling Rules

Based on the shadcn/ui design system, apply these Tailwind CSS patterns for admin interface components:

## Core Design Principles

- Clean, minimal aesthetic with subtle shadows and borders
- Consistent spacing using Tailwind's spacing scale
- Muted color palette with accent colors for actions
- Focus on readability and hierarchy

## Color Palette

```css
/* Primary Colors */
- Background: bg-background (white/slate-50)
- Foreground: text-foreground (slate-900)
- Muted: bg-muted (slate-100), text-muted-foreground (slate-500)
- Border: border-border (slate-200)
- Input: bg-input (white)
- Ring: ring-ring (slate-950)

/* Semantic Colors */
- Primary: bg-primary (slate-900), text-primary-foreground (slate-50)
- Secondary: bg-secondary (slate-100), text-secondary-foreground (slate-900)
- Destructive: bg-destructive (red-500), text-destructive-foreground (white)
- Success: bg-green-500, text-white
- Warning: bg-yellow-500, text-white
```

## Component Patterns

### Cards

```css
/* Standard card */
class="bg-white border border-slate-200 rounded-lg"

/* Card header */
class="p-6 pb-4"

/* Card content */
class="p-6 pt-0"

/* Card with hover effect */
class="bg-white border border-slate-200 rounded-lg hover:shadow-md transition-shadow"
```

### Buttons

```css
/* Primary button */
class="bg-slate-900 text-slate-50 hover:bg-slate-800 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Secondary button */
class="bg-slate-100 text-slate-900 hover:bg-slate-200 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Destructive button */
class="bg-red-500 text-white hover:bg-red-600 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2"

/* Ghost button */
class="hover:bg-slate-100 hover:text-slate-900 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Button sizes */
- Small: "px-3 py-1.5 text-xs"
- Default: "px-4 py-2 text-sm"
- Large: "px-6 py-3 text-base"
```

### Forms

```css
/* Input field */
class="flex h-10 w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

/* Textarea */
class="flex min-h-[80px] w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-background placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

/* Select */
class="flex h-10 w-full items-center justify-between rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-background placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

/* Label */
class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"

/* Form group */
class="space-y-2"
```

### Tables

```css
/* Table container */
class="relative w-full overflow-auto"

/* Table */
class="w-full caption-bottom text-sm"

/* Table header */
class="border-b border-slate-200"

/* Table header cell */
class="h-12 px-4 text-left align-middle font-medium text-slate-500 [&:has([role=checkbox])]:pr-0"

/* Table body */
class="[&_tr:last-child]:border-0"

/* Table row */
class="border-b border-slate-200 transition-colors hover:bg-slate-100/50 data-[state=selected]:bg-slate-100"

/* Table cell */
class="p-4 align-middle [&:has([role=checkbox])]:pr-0"
```

### Navigation

```css
/* Navigation menu */
class="flex items-center space-x-4 lg:space-x-6"

/* Navigation link */
class="text-sm font-medium transition-colors hover:text-slate-900 text-slate-500"

/* Active navigation link */
class="text-sm font-medium text-slate-900"

/* Breadcrumb */
class="flex items-center space-x-2 text-sm text-slate-500"

/* Breadcrumb separator */
class="h-4 w-4"
```

### Modals/Dialogs

```css
/* Dialog overlay */
class="fixed inset-0 z-50 bg-slate-900/80 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0"

/* Dialog content */
class="fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border border-slate-200 bg-white p-6 shadow-lg duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%] data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%] sm:rounded-lg"

/* Dialog header */
class="flex flex-col space-y-1.5 text-center sm:text-left"

/* Dialog title */
class="text-lg font-semibold leading-none tracking-tight"

/* Dialog description */
class="text-sm text-slate-500"
```

### Alerts/Notifications

```css
/* Alert container */
class="relative w-full rounded-lg border border-slate-200 p-4 [&>svg~*]:pl-7 [&>svg+div]:translate-y-[-3px] [&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4 [&>svg]:text-slate-950"

/* Success alert */
class="border-green-200 bg-green-50 text-green-900 [&>svg]:text-green-600"

/* Warning alert */
class="border-yellow-200 bg-yellow-50 text-yellow-900 [&>svg]:text-yellow-600"

/* Error alert */
class="border-red-200 bg-red-50 text-red-900 [&>svg]:text-red-600"

/* Info alert */
class="border-blue-200 bg-blue-50 text-blue-900 [&>svg]:text-blue-600"
```

### Badges/Status

```css
/* Default badge */
class="inline-flex items-center rounded-full border border-slate-200 px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Success badge */
class="bg-green-100 text-green-800 border-green-200"

/* Warning badge */
class="bg-yellow-100 text-yellow-800 border-yellow-200"

/* Error badge */
class="bg-red-100 text-red-800 border-red-200"

/* Secondary badge */
class="bg-slate-100 text-slate-800 border-slate-200"
```

### Layout

```css
/* Page container */
class="container mx-auto px-4 py-6"

/* Section spacing */
class="space-y-6"

/* Grid layouts */
class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"

/* Flex layouts */
class="flex items-center justify-between"
class="flex flex-col space-y-4"
class="flex items-center space-x-4"
```

## Typography

```css
/* Headings */
- h1: "scroll-m-20 text-4xl font-extrabold tracking-tight lg:text-5xl"
- h2: "scroll-m-20 border-b border-slate-200 pb-2 text-3xl font-semibold tracking-tight first:mt-0"
- h3: "scroll-m-20 text-2xl font-semibold tracking-tight"
- h4: "scroll-m-20 text-xl font-semibold tracking-tight"

/* Body text */
- Large: "text-lg text-slate-700"
- Default: "text-sm text-slate-600"
- Small: "text-xs text-slate-500"
- Muted: "text-sm text-slate-500"
```

## Spacing Guidelines

- Use consistent spacing: space-y-4, space-y-6, space-y-8
- Padding: p-4, p-6, px-4, py-2, etc.
- Margins: mb-4, mt-6, mx-auto, etc.
- Gaps: gap-4, gap-6 for grid/flex layouts

## Animation Classes

```css
/* Transitions */
class="transition-colors duration-200"
class="transition-all duration-200"
class="transition-shadow duration-200"

/* Hover effects */
class="hover:shadow-md"
class="hover:bg-slate-100"
class="hover:scale-105"
```

## Usage Examples

### Admin Dashboard Card

```html
<div class="bg-white border border-slate-200 rounded-lg  p-6">
  <div class="flex items-center justify-between mb-4">
    <h3 class="text-lg font-semibold text-slate-900">Card Title</h3>
    <span
      class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800"
      >Active</span
    >
  </div>
  <p class="text-sm text-slate-600 mb-4">Card description goes here.</p>
  <button
    class="bg-slate-900 text-slate-50 hover:bg-slate-800 px-4 py-2 rounded-md text-sm font-medium transition-colors"
  >
    Action Button
  </button>
</div>
```

### Form Section

```html
<div class="bg-white border border-slate-200 rounded-lg  p-6">
  <div class="space-y-4">
    <div class="space-y-2">
      <label class="text-sm font-medium leading-none">Email</label>
      <input
        class="flex h-10 w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
        placeholder="Enter email"
      />
    </div>
    <div class="flex justify-end space-x-2">
      <button
        class="hover:bg-slate-100 hover:text-slate-900 px-4 py-2 rounded-md text-sm font-medium transition-colors"
      >
        Cancel
      </button>
      <button
        class="bg-slate-900 text-slate-50 hover:bg-slate-800 px-4 py-2 rounded-md text-sm font-medium transition-colors"
      >
        Save
      </button>
    </div>
  </div>
</div>
```

## Integration with Existing Preferences

- Maintains your preference for bg-gray-50 cards (can be substituted with bg-slate-50)
- Continues to avoid borders in favor of clean backgrounds where appropriate
- Uses hover:bg-gray-100 pattern (can use hover:bg-slate-100)
- Follows Tailwind CSS approach you prefer

# shadcn/ui Admin Styling Rules

Based on the shadcn/ui design system, apply these Tailwind CSS patterns for admin interface components:

## Core Design Principles

- Clean, minimal aesthetic with subtle shadows and borders
- Consistent spacing using Tailwind's spacing scale
- Muted color palette with accent colors for actions
- Focus on readability and hierarchy

## Color Palette

```css
/* Primary Colors */
- Background: bg-background (white/slate-50)
- Foreground: text-foreground (slate-900)
- Muted: bg-muted (slate-100), text-muted-foreground (slate-500)
- Border: border-border (slate-200)
- Input: bg-input (white)
- Ring: ring-ring (slate-950)

/* Semantic Colors */
- Primary: bg-primary (slate-900), text-primary-foreground (slate-50)
- Secondary: bg-secondary (slate-100), text-secondary-foreground (slate-900)
- Destructive: bg-destructive (red-500), text-destructive-foreground (white)
- Success: bg-green-500, text-white
- Warning: bg-yellow-500, text-white
```

## Component Patterns

### Cards

```css
/* Standard card */
class="bg-white border border-slate-200 rounded-lg "

/* Card header */
class="p-6 pb-4"

/* Card content */
class="p-6 pt-0"

/* Card with hover effect */
class="bg-white border border-slate-200 rounded-lg  hover:shadow-md transition-shadow"
```

### Buttons

```css
/* Primary button */
class="bg-slate-900 text-slate-50 hover:bg-slate-800 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Secondary button */
class="bg-slate-100 text-slate-900 hover:bg-slate-200 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Destructive button */
class="bg-red-500 text-white hover:bg-red-600 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2"

/* Ghost button */
class="hover:bg-slate-100 hover:text-slate-900 px-4 py-2 rounded-md text-sm font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Button sizes */
- Small: "px-3 py-1.5 text-xs"
- Default: "px-4 py-2 text-sm"
- Large: "px-6 py-3 text-base"
```

### Forms

```css
/* Input field */
class="flex h-10 w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-background file:border-0 file:bg-transparent file:text-sm file:font-medium placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

/* Textarea */
class="flex min-h-[80px] w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-background placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

/* Select */
class="flex h-10 w-full items-center justify-between rounded-md border border-slate-200 bg-white px-3 py-2 text-sm ring-offset-background placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2 disabled:cursor-not-allowed disabled:opacity-50"

/* Label */
class="text-sm font-medium leading-none peer-disabled:cursor-not-allowed peer-disabled:opacity-70"

/* Form group */
class="space-y-2"
```

### Tables

```css
/* Table container */
class="relative w-full overflow-auto"

/* Table */
class="w-full caption-bottom text-sm"

/* Table header */
class="border-b border-slate-200"

/* Table header cell */
class="h-12 px-4 text-left align-middle font-medium text-slate-500 [&:has([role=checkbox])]:pr-0"

/* Table body */
class="[&_tr:last-child]:border-0"

/* Table row */
class="border-b border-slate-200 transition-colors hover:bg-slate-100/50 data-[state=selected]:bg-slate-100"

/* Table cell */
class="p-4 align-middle [&:has([role=checkbox])]:pr-0"
```

### Navigation

```css
/* Navigation menu */
class="flex items-center space-x-4 lg:space-x-6"

/* Navigation link */
class="text-sm font-medium transition-colors hover:text-slate-900 text-slate-500"

/* Active navigation link */
class="text-sm font-medium text-slate-900"

/* Breadcrumb */
class="flex items-center space-x-2 text-sm text-slate-500"

/* Breadcrumb separator */
class="h-4 w-4"
```

### Modals/Dialogs

```css
/* Dialog overlay */
class="fixed inset-0 z-50 bg-slate-900/80 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0"

/* Dialog content */
class="fixed left-[50%] top-[50%] z-50 grid w-full max-w-lg translate-x-[-50%] translate-y-[-50%] gap-4 border border-slate-200 bg-white p-6 shadow-lg duration-200 data-[state=open]:animate-in data-[state=closed]:animate-out data-[state=closed]:fade-out-0 data-[state=open]:fade-in-0 data-[state=closed]:zoom-out-95 data-[state=open]:zoom-in-95 data-[state=closed]:slide-out-to-left-1/2 data-[state=closed]:slide-out-to-top-[48%] data-[state=open]:slide-in-from-left-1/2 data-[state=open]:slide-in-from-top-[48%] sm:rounded-lg"

/* Dialog header */
class="flex flex-col space-y-1.5 text-center sm:text-left"

/* Dialog title */
class="text-lg font-semibold leading-none tracking-tight"

/* Dialog description */
class="text-sm text-slate-500"
```

### Alerts/Notifications

```css
/* Alert container */
class="relative w-full rounded-lg border border-slate-200 p-4 [&>svg~*]:pl-7 [&>svg+div]:translate-y-[-3px] [&>svg]:absolute [&>svg]:left-4 [&>svg]:top-4 [&>svg]:text-slate-950"

/* Success alert */
class="border-green-200 bg-green-50 text-green-900 [&>svg]:text-green-600"

/* Warning alert */
class="border-yellow-200 bg-yellow-50 text-yellow-900 [&>svg]:text-yellow-600"

/* Error alert */
class="border-red-200 bg-red-50 text-red-900 [&>svg]:text-red-600"

/* Info alert */
class="border-blue-200 bg-blue-50 text-blue-900 [&>svg]:text-blue-600"
```

### Badges/Status

```css
/* Default badge */
class="inline-flex items-center rounded-full border border-slate-200 px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"

/* Success badge */
class="bg-green-100 text-green-800 border-green-200"

/* Warning badge */
class="bg-yellow-100 text-yellow-800 border-yellow-200"

/* Error badge */
class="bg-red-100 text-red-800 border-red-200"

/* Secondary badge */
class="bg-slate-100 text-slate-800 border-slate-200"
```

### Layout

```css
/* Page container */
class="container mx-auto px-4 py-6"

/* Section spacing */
class="space-y-6"

/* Grid layouts */
class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6"

/* Flex layouts */
class="flex items-center justify-between"
class="flex flex-col space-y-4"
class="flex items-center space-x-4"
```

## Typography

```css
/* Headings */
- h1: "scroll-m-20 text-4xl font-extrabold tracking-tight lg:text-5xl"
- h2: "scroll-m-20 border-b border-slate-200 pb-2 text-3xl font-semibold tracking-tight first:mt-0"
- h3: "scroll-m-20 text-2xl font-semibold tracking-tight"
- h4: "scroll-m-20 text-xl font-semibold tracking-tight"

/* Body text */
- Large: "text-lg text-slate-700"
- Default: "text-sm text-slate-600"
- Small: "text-xs text-slate-500"
- Muted: "text-sm text-slate-500"
```

## Spacing Guidelines

- Use consistent spacing: space-y-4, space-y-6, space-y-8
- Padding: p-4, p-6, px-4, py-2, etc.
- Margins: mb-4, mt-6, mx-auto, etc.
- Gaps: gap-4, gap-6 for grid/flex layouts

## Animation Classes

```css
/* Transitions */
class="transition-colors duration-200"
class="transition-all duration-200"
class="transition-shadow duration-200"

/* Hover effects */
class="hover:shadow-md"
class="hover:bg-slate-100"
class="hover:scale-105"
```

## Usage Examples

### Admin Dashboard Card

```html
<div class="bg-white border border-slate-200 rounded-lg p-6">
  <div class="flex items-center justify-between mb-4">
    <h3 class="text-lg font-semibold text-slate-900">Card Title</h3>
    <span
      class="inline-flex items-center rounded-full bg-green-100 px-2.5 py-0.5 text-xs font-medium text-green-800"
      >Active</span
    >
  </div>
  <p class="text-sm text-slate-600 mb-4">Card description goes here.</p>
  <button
    class="bg-slate-900 text-slate-50 hover:bg-slate-800 px-4 py-2 rounded-md text-sm font-medium transition-colors"
  >
    Action Button
  </button>
</div>
```

### Form Section

```html
<div class="bg-white border border-slate-200 rounded-lg p-6">
  <div class="space-y-4">
    <div class="space-y-2">
      <label class="text-sm font-medium leading-none">Email</label>
      <input
        class="flex h-10 w-full rounded-md border border-slate-200 bg-white px-3 py-2 text-sm placeholder:text-slate-500 focus:outline-none focus:ring-2 focus:ring-slate-950 focus:ring-offset-2"
        placeholder="Enter email"
      />
    </div>
    <div class="flex justify-end space-x-2">
      <button
        class="hover:bg-slate-100 hover:text-slate-900 px-4 py-2 rounded-md text-sm font-medium transition-colors"
      >
        Cancel
      </button>
      <button
        class="bg-slate-900 text-slate-50 hover:bg-slate-800 px-4 py-2 rounded-md text-sm font-medium transition-colors"
      >
        Save
      </button>
    </div>
  </div>
</div>
```

## Integration with Existing Preferences

- Maintains your preference for bg-gray-50 cards (can be substituted with bg-slate-50)
- Continues to avoid borders in favor of clean backgrounds where appropriate
- Uses hover:bg-gray-100 pattern (can use hover:bg-slate-100)
- Follows Tailwind CSS approach you prefer
