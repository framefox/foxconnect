# Email Template Fix Summary

## Issue
Emails sent from the production Heroku app were rendering incorrectly:
- Content appeared duplicated
- Layout styling was broken
- Some CSS worked (colors, fonts) but layout structure failed

## Root Causes

### 1. Double Yield in Mailer Layout
The `mailer.html.erb` layout had `<%= yield %>` appearing twice:
- Once on line 7 inside the styled wrapper
- Again on line 25 in the body tag

This caused all email content to be rendered twice in the email.

### 2. Backwards HTML Structure
The HTML structure was inverted:
- Styled content wrapper came first (lines 1-14)
- DOCTYPE and HTML tags came after (lines 15-27)

This is invalid HTML and caused rendering issues.

### 3. Email CSS Compatibility Issues
The email templates used CSS properties that are poorly supported by email clients:
- `display: flex` - Not supported in most email clients
- `gap` property - Not supported
- `align-items`, `justify-content` - Limited support

**Email clients have very limited CSS support compared to web browsers.**

## Solutions Implemented

### 1. Added Premailer-Rails Gem
Instead of writing inline styles manually, we now use `premailer-rails` which:
- Automatically converts CSS to inline styles at email send time
- Keeps email templates clean and maintainable
- Allows writing normal CSS in stylesheets

**Added to Gemfile:**
```ruby
gem "premailer-rails"
```

### 2. Created Email Stylesheet (`app/assets/stylesheets/mailer.css`)
Created a dedicated stylesheet with email-safe CSS classes:
- `.email-container`, `.email-header`, `.email-footer` - Layout structure
- `.alert`, `.alert-error`, `.alert-warning`, `.alert-success` - Alert boxes
- `.badge`, `.badge-success`, `.badge-warning`, etc. - Status badges
- `.order-items`, `.item-name`, `.item-sku`, etc. - Item display
- `.btn`, `.btn-wrapper` - Call-to-action buttons

**All styles are email-safe and will be inlined by premailer-rails.**

### 3. Fixed Mailer Layout (`app/views/layouts/mailer.html.erb`)
- Restructured to have proper HTML document structure
- Single `<%= yield %>` in the correct location
- Added `<%= stylesheet_link_tag "mailer" %>` to load email CSS
- Used table-based layout (the email-safe standard)
- Proper viewport meta tag for mobile devices

### 4. Refactored Email Templates
Converted both email templates to use semantic classes instead of inline styles:
- `app/views/order_mailer/draft_imported.html.erb`
- `app/views/order_mailer/fulfillment_notification.html.erb`

**Changes:**
- Replaced inline styles with semantic CSS classes
- Kept table-based structure (required for email clients)
- Much cleaner and more maintainable code
- Easier to update styles across all emails

**Before:**
```erb
<div style="margin-bottom:12px;padding:10px 12px;background:#fef3c7;border:1px solid #fde68a;border-radius:6px;color:#92400e;">
  Action needed: <%= pluralize(items_without_mapping.sum(&:quantity), 'item') %> require a connected product and image.
</div>
```

**After:**
```erb
<div class="alert alert-warning">
  Action needed: <%= pluralize(items_without_mapping.sum(&:quantity), 'item') %> require a connected product and image.
</div>
```

## How Premailer-Rails Works

When an email is sent, premailer-rails automatically:
1. Loads the CSS from `mailer.css`
2. Converts all CSS rules to inline styles
3. Optimizes the HTML for email clients
4. Sends the email with inline styles

**This happens transparently at send time** - no manual work required.

## Why Tables for Email?

Email clients (Gmail, Outlook, Apple Mail, etc.) have very limited CSS support:
- No flexbox
- No grid
- Limited positioning
- Inconsistent float behavior

**Table-based layouts are the only reliable way to create structured layouts in emails.**

## Testing Recommendations

1. **Test in multiple email clients:**
   - Gmail (web, iOS, Android)
   - Apple Mail (macOS, iOS)
   - Outlook (web, desktop)
   - Outlook.com

2. **Use email testing tools:**
   - Litmus
   - Email on Acid
   - Mailtrap

3. **Test responsive behavior** on mobile devices

## Best Practices for Future Email Templates

### 1. Write CSS in the Stylesheet
Add new email styles to `app/assets/stylesheets/mailer.css`:
```css
.my-new-class {
  padding: 12px;
  background: #f0f0f0;
  border-radius: 6px;
}
```

### 2. Use Semantic Class Names
Use classes in your email templates instead of inline styles:
```erb
<div class="my-new-class">
  Content here
</div>
```

### 3. Table-Based Layouts Only
Always use tables for structural layouts (not divs with flexbox/grid):
```erb
<table width="100%" cellpadding="0" cellspacing="0" border="0">
  <tr>
    <td>Content</td>
  </tr>
</table>
```

### 4. Email-Safe CSS Properties
**Safe to use:**
- Colors, fonts, text properties ✓
- Padding, margin (with caution) ✓
- Borders, backgrounds ✓
- Width, height ✓

**Avoid:**
- Flexbox, grid ✗
- Position (absolute/fixed) ✗
- Transform, animation ✗
- Float (inconsistent) ⚠️

### 5. Testing
Always test across multiple email clients before deploying:
- Gmail (web, iOS, Android)
- Apple Mail (macOS, iOS)
- Outlook (web, desktop)
- Outlook.com

### 6. Images
- Always include `width` and `height` attributes
- Keep file sizes small (< 200kb per image)
- Use absolute URLs for production

### 7. Updating Styles
To update email styles:
1. Edit `app/assets/stylesheets/mailer.css`
2. Restart Rails server in development
3. Preview with letter_opener
4. Deploy - premailer-rails handles the rest

## Files Modified

- **Gemfile** - Added `premailer-rails`
- **app/assets/stylesheets/mailer.css** - New email stylesheet
- **app/views/layouts/mailer.html.erb** - Complete restructure with stylesheet
- **app/views/order_mailer/draft_imported.html.erb** - Refactored to use CSS classes
- **app/views/order_mailer/fulfillment_notification.html.erb** - Refactored to use CSS classes

## Deployment

1. Run `bundle install` on production to install premailer-rails
2. Deploy the updated files
3. Emails will automatically be inlined by premailer-rails at send time
4. No other configuration needed

## Development Preview

In development, you can preview emails with letter_opener:
```ruby
# In console or trigger an email action
OrderMailer.with(order_id: order.id).draft_imported.deliver_now
```

The email will open in your browser with all styles properly inlined.

