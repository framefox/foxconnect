# Missing frame preview recovery

A mapping can have valid artwork and crop data while lacking `preview_url`, the
renderer URL needed by `framed_preview_*`. Artwork existence must not be inferred
from the framed-preview URL.

- Interactive create/upsert and update recover a missing URL before saving artwork.
- Apply image resolves each target SKU's missing URL before changing any mappings,
  reuses lookups within the request, and applies all image copies transactionally.
- Bulk overwrite preserves a valid same-SKU URL. When the SKU changes and the
  supplied preview is missing, it retrieves that SKU's URL before changing a
  mapping that already has artwork. A lookup failure is recorded on the bulk job
  and leaves that mapping unchanged.
- Other writes, including order snapshots and imports, enqueue recovery after
  commit. Order creation does not depend on the preview API. The recovery job
  retries temporary failures and rechecks the SKU, country, artwork, and current
  preview before saving, so it cannot overwrite a concurrent edit.
- Product and order cards show attached artwork and “Frame preview unavailable”
  when no framed preview can be generated. They only offer “Add image” when no
  artwork is attached.

## Existing records

Run `bin/rails variant_mappings:repair_missing_previews` in the environment to
repair. This queues recovery for existing mappings and order snapshots with an
image and an empty renderer URL. It does not change artwork, crops, products,
prices, or dimensions. Re-running is safe; already-repaired records are skipped.

No database migration is required. Deploy the web and worker code together, then
run the repair task to cover records created before preview recovery was added.
