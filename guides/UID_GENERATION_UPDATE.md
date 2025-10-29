# UID Generation Update

## Overview

Updated UID generation for both Orders and Stores to use more meaningful and predictable identifiers.

## Implementation Date

October 23, 2025

## Changes Made

### 1. Order UIDs - Random 8-Digit Numbers

**Previous Behavior:**
- Random 10-character alphanumeric UIDs (e.g., `717we1jsyf`, `l7rvnhkoxj`)

**New Behavior:**
- Random 8-digit numeric UIDs (e.g., `12345678`, `87654321`)
- Range: 10000000 to 99999999
- Uniqueness is enforced by checking for collisions

**Updated Files:**
- `app/models/order.rb` - Modified `generate_uid` method to use random 8-digit numbers
- `db/migrate/20251023020000_update_order_uids_to_incremental.rb` - Migration to update existing orders (from old format)

**Code Change:**
```ruby
def generate_uid
  return if uid.present?

  # Generate random 8-digit number (10000000 to 99999999)
  loop do
    self.uid = rand(10000000..99999999).to_s
    break unless Order.exists?(uid: uid)
  end
end
```

### 2. Store UIDs - Domain-Based

**Previous Behavior:**
- Random 8-character alphanumeric UIDs (e.g., `k7xm9p2a`, `q4n8r1vh`)

**New Behavior:**
- UIDs based on the store's domain/identifier
- For Shopify stores: Uses subdomain part only (e.g., `ricky-robinson-2`, `chuck-norris-artist`)
- For Wix stores: Uses `wix_site_id`
- For Squarespace stores: Uses subdomain part of `squarespace_domain`
- If conflicts occur, appends `-1`, `-2`, etc.

**Updated Files:**
- `app/models/store.rb` - Modified `generate_uid` method to use domain-based UIDs
- `db/migrate/20251023020001_update_store_uids_to_domain_based.rb` - Migration to update existing stores

**Code Change:**
```ruby
def generate_uid
  return if uid.present?

  # Determine base UID from platform-specific domain
  base_uid = case platform
  when "shopify"
    # Extract subdomain (part before .myshopify.com)
    shopify_domain&.sub(/\.myshopify\.com$/, '')
  when "wix"
    wix_site_id
  when "squarespace"
    # Extract subdomain if it's a squarespace domain
    squarespace_domain&.sub(/\.squarespace\.com$/, '')
  else
    # Fallback to random alphanumeric for unknown platforms
    SecureRandom.alphanumeric(8).downcase
  end

  # Handle nil base_uid (shouldn't happen but be defensive)
  if base_uid.nil?
    base_uid = SecureRandom.alphanumeric(8).downcase
  end

  # Check for conflicts and add suffix if needed
  candidate_uid = base_uid
  suffix = 1

  while Store.exists?(uid: candidate_uid)
    candidate_uid = "#{base_uid}-#{suffix}"
    suffix += 1
  end

  self.uid = candidate_uid
end
```

## Migration Results

### Orders
- Existing orders retain their current UIDs (migrated from alphanumeric to incremental format)
- New orders created after this change will use random 8-digit numbers

### Stores
- Shopify stores now use subdomain as UID:
  - `ricky-robinson-2.myshopify.com` → `ricky-robinson-2`
  - `chuck-norris-artist.myshopify.com` → `chuck-norris-artist`

## Benefits

### Order UIDs
1. **Numeric**: Clean, all-digit identifiers
2. **Fixed Length**: Always 8 digits for consistency
3. **Non-Sequential**: Random generation prevents guessing order IDs
4. **Professional**: Standard order number format

### Store UIDs
1. **Meaningful**: UIDs reflect the actual store domain
2. **Memorable**: Easier to identify stores at a glance
3. **Conflict Handling**: Automatic suffix addition if duplicates exist
4. **URL-Friendly**: Clean URLs like `/stores/ricky-robinson-2`

## Examples

### Order URLs
- `/orders/12345678`
- `/orders/87654321`
- `/orders/45678901`

### Store URLs
- `/stores/ricky-robinson-2`
- `/stores/chuck-norris-artist`

## Backward Compatibility

- All existing URLs automatically redirect to use the new UIDs
- Database relationships (foreign keys) remain unchanged
- The `to_param` method ensures Rails routing works seamlessly

