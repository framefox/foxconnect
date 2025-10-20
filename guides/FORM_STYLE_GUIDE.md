# Form Style Guide

## Overview

This style guide defines the consistent design patterns for all forms across the FrameFox Pro application. The styles are based on modern, accessible design principles with a focus on clarity and usability.

## Form Container

```erb
<div class="max-w-2xl mx-auto bg-white rounded-2xl shadow-sm border border-slate-200 p-8">
  <!-- Form content -->
</div>
```

**Properties:**

- Max width: `max-w-2xl` (672px)
- Background: `bg-white`
- Border radius: `rounded-2xl` (1rem)
- Shadow: `shadow-sm` (subtle drop shadow)
- Border: `border border-slate-200`
- Padding: `p-8` (2rem all sides)
- Centered: `mx-auto`

## Form Header

```erb
<div class="mb-6">
  <h1 class="text-3xl font-bold text-slate-900 mb-2">Form Title</h1>
  <p class="text-slate-600">Help text or description goes here.</p>
</div>
```

**Properties:**

- Title: `text-3xl font-bold text-slate-900`
- Description: `text-slate-600`
- Bottom margin: `mb-6` between header and form fields

## Form Fields

### Label

```erb
<label for="field-id" class="block text-sm font-semibold text-slate-900 mb-2">
  Field Label
</label>
```

**Properties:**

- Display: `block`
- Size: `text-sm`
- Weight: `font-semibold`
- Color: `text-slate-900`
- Spacing: `mb-2` (margin bottom)

### Text Input

```erb
<input
  type="text"
  id="field-id"
  name="field_name"
  class="block w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:border-transparent transition-colors"
  placeholder="Placeholder text"
/>
```

**Properties:**

- Display: `block w-full`
- Padding: `px-4 py-3` (1rem horizontal, 0.75rem vertical)
- Background: `bg-white`
- Border: `border border-slate-300`
- Border radius: `rounded-lg` (0.5rem)
- Text: `text-slate-900`
- Placeholder: `placeholder-slate-400`
- Focus states:
  - `focus:outline-none`
  - `focus:ring-2 focus:ring-slate-500`
  - `focus:border-transparent`
- Transition: `transition-colors`

### Textarea

```erb
<textarea
  id="field-id"
  name="field_name"
  rows="6"
  class="block w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:border-transparent transition-colors resize-none"
  placeholder="Placeholder text"
></textarea>
```

**Properties:**

- Same as text input plus:
- Resize: `resize-none` (prevent manual resizing)
- Minimum rows: `rows="6"` or appropriate for context

### Character Counter

```erb
<div class="mt-2 text-sm text-slate-500">
  <span id="char-count">0</span>/100 characters
</div>
```

**Properties:**

- Margin top: `mt-2`
- Size: `text-sm`
- Color: `text-slate-500`

### Help Text

```erb
<p class="mt-2 text-sm text-slate-500">
  Include steps to reproduce, expected behavior, and what actually happened.
</p>
```

**Properties:**

- Margin top: `mt-2`
- Size: `text-sm`
- Color: `text-slate-500`

### Field Wrapper

```erb
<div class="mb-6">
  <label>...</label>
  <input>...</input>
  <p class="help-text">...</p>
</div>
```

**Properties:**

- Bottom margin: `mb-6` between fields

## Form Actions

### Button Group

```erb
<div class="flex items-center gap-4 mt-8">
  <!-- Buttons -->
</div>
```

**Properties:**

- Layout: `flex items-center`
- Gap: `gap-4` (1rem between buttons)
- Top margin: `mt-8` (separate from fields)

### Primary Button

```erb
<button
  type="submit"
  class="px-6 py-3 bg-slate-900 text-white font-medium rounded-lg hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 transition-colors"
>
  Submit
</button>
```

**Properties:**

- Padding: `px-6 py-3`
- Background: `bg-slate-900`
- Text: `text-white font-medium`
- Border radius: `rounded-lg`
- Hover: `hover:bg-slate-800`
- Focus: `focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2`
- Transition: `transition-colors`

### Secondary Button

```erb
<button
  type="button"
  class="px-6 py-3 bg-white text-slate-700 font-medium border border-slate-300 rounded-lg hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 transition-colors"
>
  Reset
</button>
```

**Properties:**

- Padding: `px-6 py-3`
- Background: `bg-white`
- Text: `text-slate-700 font-medium`
- Border: `border border-slate-300`
- Border radius: `rounded-lg`
- Hover: `hover:bg-slate-50`
- Focus: `focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2`
- Transition: `transition-colors`

## Validation States

### Error State

```erb
<input
  class="... border-red-300 focus:ring-red-500"
  aria-invalid="true"
  aria-describedby="field-error"
/>
<p id="field-error" class="mt-2 text-sm text-red-600">
  <i class="fa-solid fa-circle-exclamation mr-1"></i>
  Error message here
</p>
```

**Properties:**

- Border: `border-red-300`
- Focus ring: `focus:ring-red-500`
- Error text: `text-sm text-red-600`
- Icon: Use Font Awesome error icon

### Success State

```erb
<input
  class="... border-green-300 focus:ring-green-500"
/>
<p class="mt-2 text-sm text-green-600">
  <i class="fa-solid fa-circle-check mr-1"></i>
  Success message
</p>
```

**Properties:**

- Border: `border-green-300`
- Focus ring: `focus:ring-green-500`
- Success text: `text-sm text-green-600`

### Disabled State

```erb
<input
  disabled
  class="... bg-slate-100 text-slate-500 cursor-not-allowed"
/>
```

**Properties:**

- Background: `bg-slate-100`
- Text: `text-slate-500`
- Cursor: `cursor-not-allowed`

## Hint Alert

```erb
<div class="my-6 border border-slate-200 rounded p-6 bg-slate-50/50 leading-6 text-center">
  <p class="text-slate-700">
    Your helpful hint or informational message goes here.
  </p>
</div>
```

**Properties:**

- Margin: `my-6` (1.5rem top/bottom, equivalent to 24px)
- Border: `border border-slate-200` (1px solid light gray)
- Border radius: `rounded` (0.25rem, equivalent to 4px)
- Padding: `p-6` (1.5rem all sides, equivalent to 1.5em)
- Background: `bg-slate-50/50` (light gray with 50% opacity for subtle texture)
- Line height: `leading-6` (1.5 line height)
- Text align: `text-center`
- Text color: `text-slate-700`

**Note:** For a striped background pattern (like `bg-stripes-light.png`), you can add a custom background image:

```erb
<div class="my-6 border border-slate-200 rounded p-6 leading-6 text-center" style="background-image: url('<%= asset_path('bg-stripes-light.png') %>');">
  <p class="text-slate-700">Your hint message</p>
</div>
```

Or use a repeating gradient pattern:

```erb
<div class="my-6 border border-slate-200 rounded p-6 leading-6 text-center" style="background: repeating-linear-gradient(45deg, #f8fafc, #f8fafc 10px, #f1f5f9 10px, #f1f5f9 20px);">
  <p class="text-slate-700">Your hint message</p>
</div>
```

## Select/Dropdown

```erb
<select
  id="field-id"
  name="field_name"
  class="block w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-slate-900 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:border-transparent transition-colors"
>
  <option value="">Select an option</option>
  <option value="1">Option 1</option>
</select>
```

**Properties:**

- Same as text input styling

## Checkbox

```erb
<div class="flex items-start">
  <input
    type="checkbox"
    id="checkbox-id"
    class="mt-1 h-4 w-4 text-slate-900 border-slate-300 rounded focus:ring-slate-500"
  />
  <label for="checkbox-id" class="ml-3 text-sm text-slate-700">
    Checkbox label text
  </label>
</div>
```

**Properties:**

- Size: `h-4 w-4`
- Color: `text-slate-900`
- Border: `border-slate-300`
- Border radius: `rounded`
- Focus: `focus:ring-slate-500`
- Label margin: `ml-3`

## Radio Button

```erb
<div class="flex items-start">
  <input
    type="radio"
    id="radio-id"
    name="radio_group"
    class="mt-1 h-4 w-4 text-slate-900 border-slate-300 focus:ring-slate-500"
  />
  <label for="radio-id" class="ml-3 text-sm text-slate-700">
    Radio option text
  </label>
</div>
```

**Properties:**

- Same as checkbox but naturally circular

## File Upload

```erb
<div class="flex items-center justify-center w-full">
  <label
    for="file-upload"
    class="flex flex-col items-center justify-center w-full h-32 border-2 border-slate-300 border-dashed rounded-lg cursor-pointer bg-slate-50 hover:bg-slate-100 transition-colors"
  >
    <div class="flex flex-col items-center justify-center pt-5 pb-6">
      <i class="fa-solid fa-cloud-arrow-up text-3xl text-slate-400 mb-2"></i>
      <p class="text-sm text-slate-600 font-medium">Click to upload</p>
      <p class="text-xs text-slate-500">or drag and drop</p>
    </div>
    <input id="file-upload" type="file" class="hidden" />
  </label>
</div>
```

**Properties:**

- Border: `border-2 border-slate-300 border-dashed`
- Border radius: `rounded-lg`
- Background: `bg-slate-50`
- Hover: `hover:bg-slate-100`

## Color Palette

### Text Colors

- Primary text: `text-slate-900`
- Secondary text: `text-slate-600`
- Muted text: `text-slate-500`
- Placeholder: `text-slate-400`
- Error: `text-red-600`
- Success: `text-green-600`

### Border Colors

- Default: `border-slate-300`
- Focus: `border-transparent` (when ring is active)
- Error: `border-red-300`
- Success: `border-green-300`

### Background Colors

- Input: `bg-white`
- Disabled: `bg-slate-100`
- Container: `bg-white`

### Focus Ring

- Color: `ring-slate-500`
- Width: `ring-2`
- Offset: `ring-offset-2` (for buttons)

## Accessibility Requirements

1. **Always use labels**: Every input must have an associated label
2. **Use proper input types**: email, tel, url, number, etc.
3. **Aria attributes**: Add `aria-invalid`, `aria-describedby` for errors
4. **Focus states**: All interactive elements must have visible focus states
5. **Error messages**: Link errors to inputs with `aria-describedby`
6. **Keyboard navigation**: All form controls must be keyboard accessible

## Responsive Considerations

- Mobile: Form containers should have horizontal padding
- Consider single-column layouts on mobile
- Buttons may stack vertically on small screens
- Reduce padding on smaller screens if needed

## Complete Form Example

```erb
<div class="max-w-2xl mx-auto bg-white rounded-2xl shadow-sm border border-slate-200 p-8">
  <!-- Header -->
  <div class="mb-6">
    <h1 class="text-3xl font-bold text-slate-900 mb-2">Form Title</h1>
    <p class="text-slate-600">Description text goes here.</p>
  </div>

  <%= form_with url: "#", method: :post do |f| %>
    <!-- Text Field -->
    <div class="mb-6">
      <%= f.label :title, "Field Label", class: "block text-sm font-semibold text-slate-900 mb-2" %>
      <%= f.text_field :title,
        class: "block w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:border-transparent transition-colors",
        placeholder: "Enter text here"
      %>
    </div>

    <!-- Textarea -->
    <div class="mb-6">
      <%= f.label :description, "Description", class: "block text-sm font-semibold text-slate-900 mb-2" %>
      <%= f.text_area :description,
        rows: 6,
        class: "block w-full px-4 py-3 bg-white border border-slate-300 rounded-lg text-slate-900 placeholder-slate-400 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:border-transparent transition-colors resize-none",
        placeholder: "Enter description"
      %>
      <p class="mt-2 text-sm text-slate-500">
        Help text goes here.
      </p>
    </div>

    <!-- Actions -->
    <div class="flex items-center gap-4 mt-8">
      <%= f.submit "Submit",
        class: "px-6 py-3 bg-slate-900 text-white font-medium rounded-lg hover:bg-slate-800 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 transition-colors"
      %>
      <button
        type="button"
        class="px-6 py-3 bg-white text-slate-700 font-medium border border-slate-300 rounded-lg hover:bg-slate-50 focus:outline-none focus:ring-2 focus:ring-slate-500 focus:ring-offset-2 transition-colors"
      >
        Reset
      </button>
    </div>
  <% end %>
</div>
```

## Notes

- Always test forms with keyboard navigation
- Ensure proper tab order
- Test with screen readers when possible
- Consider adding loading states for submit buttons
- Show clear success/error feedback after submission
