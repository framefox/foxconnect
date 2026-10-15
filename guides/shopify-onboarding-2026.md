# Shopify onboarding upgrade — 15 October 2026

## Implemented

- GraphQL and webhook API version 2026-10; shopify_api 16.3 and shopify_app 23.0.3.
- Expiring offline tokens for new OAuth sessions, encrypted refresh tokens, expiry persistence, and refresh-aware merchant sessions. Existing non-expiring tokens require the migration task below.
- Store the actual OAuth scope grant; the admin connection test fetches the live grant and verifies required permissions and saved fulfillment registration. Write permissions imply corresponding read permissions.
- Production TOML now tracked (client ID is public, secrets remain in environment variables), with matching scopes and product-delete/fulfillment subscriptions.
- Inventory activation uses an idempotency key. Fulfillment toggles enqueue retryable inventory jobs, preserving the operation key across retries and ignoring superseded operations.
- Order-import and fulfillment-request webhooks enqueue retryable jobs. Failed deliveries remain retryable; completed deliveries and queued jobs are deduplicated. Processing errors and completion are recorded in webhook logs. A ten-minute Sidekiq recovery sweep requeues interrupted/uncompleted merchant deliveries, including the database-to-Redis enqueue gap. Shopify callbacks and topic-based fulfillment events both work.
- Production order/fulfillment webhooks verify signatures against country-specific secrets and scope records to the authenticated production shop's country.
- Pagination for imported orders, assigned fulfillment requests, outbound fulfillment orders and line items, draft shipping lines, and completed draft order lines. Catalog queries use smaller pages to reduce requested GraphQL cost.
- API errors/missing results no longer count as successful fulfillment decisions or draft-order updates. Failed shipping calculations block draft completion. Draft shipping inputs over Shopify's 250-item input-array limit fail explicitly and need splitting instead of charging shipping on a truncated order.
- Deprecated productUpdate input and Shop.assignedFulfillmentOrders queries replaced.

## Production rollout — required before onboarding

These changes have only been exercised locally with mocked Shopify responses. No production deployment, app configuration release, token migration, or merchant transaction was performed.

1. Configure `SHOPIFY_PRODUCTION_WEBHOOK_SECRET_NZ` and `SHOPIFY_PRODUCTION_WEBHOOK_SECRET_AU` in the web process environment. Use the signing secret for the actual webhook subscription in each Framefox production store: the creating app's secret for API subscriptions, or the admin webhook signing secret for admin-created subscriptions. **These are not access tokens.** Missing secrets intentionally cause HTTP 401; configure them before deploying.
2. Verify `remote_shopify_domain_nz` and `remote_shopify_domain_au` match the exact `*.myshopify.com` domains in webhook headers. Verify `SHOPIFY_API_KEY`, `SHOPIFY_API_SECRET`, and `SHOPIFY_HOST` belong to the production Connect app. `FULFILLMENT_CALLBACK_HOST`, if set, must be a publicly reachable HTTPS origin.
3. Deploy with `bundle install` and `bin/rails db:migrate`; restart web and Sidekiq workers together. The new token columns must exist before the new app code serves requests. Preserve existing Active Record encryption keys; refresh tokens use the same encryption setup as webhook payloads.
4. Review and release `shopify.app.production.toml` with Shopify CLI (`shopify app deploy --config production`). This is separate from deploying Rails. Confirm the production client ID and redirect URL before releasing. New permissions can require existing merchants to reconnect.
5. For Connect's merchant OAuth installations, run `bin/rails shopify:migrate_tokens` after deployment. It skips migrated/inactive stores, locks each store during migration, and prints only store IDs. Reconnect any invalid/revoked installations. Do not roll back to code that drops refresh tokens after migrating. Framefox's separate NZ/AU custom-app credentials are not migrated by this task.
6. Use the admin connection test for each store to replace historically assumed scopes with Shopify's actual grant. Reconnect missing grants and retry `RegisterFulfillmentServiceJob` for incomplete registration. The test is a permissions/basic setup check, not an end-to-end shipping guarantee.
7. In Shopify's Dev Dashboard, confirm distribution type, API-health alerts and protected customer data approval (names, addresses, email and phone). These cannot be established from source code.

## Development-store acceptance test

- Install from scratch, approve permissions, confirm store ownership and Framefox location registration.
- Confirm the saved grant matches `currentAppInstallation.accessScopes`; reconnect with a reduced grant and ensure the connection check fails.
- Exercise OAuth expiry/refresh and reconnect after uninstall. Confirm tokens and refresh tokens never appear in logs.
- Import a catalog with multiple product pages and more than 250 variants on a product; update/delete a product and reconcile the catalog.
- Enable/disable fulfillment, retry an inventory job, and rapidly toggle a variant to verify superseded jobs are ignored.
- Place an order with a real shipping address and verify import. Test large orders, split fulfillment orders and partial shipments.
- Submit fulfillment and cancellation requests through both delivery formats; temporarily deny an API scope and confirm failed work is visible/retried.
- Send the same webhook twice, then simulate a failed first attempt. Verify one completed effect and eventual recovery.
- Calculate draft shipping and complete the production draft; verify all line-item costs and IDs are saved.
- Deliver a signed production fulfillment with tracking and verify the customer's Shopify store. Verify wrong-shop, unsigned and incorrectly signed production requests are rejected.

## Remaining operational limitations

- Protected customer data approval and actual deployed subscriptions/permissions require dashboard/live-store verification.
- Existing customer data-request/redaction handlers notify admins but still depend on a manual fulfillment process; the organization must confirm ownership and completion of these requests. This upgrade does not invent a customer-data retention policy or automatically delete historical customer records.
- Existing production fulfillment processing still performs outbound sync inline. An outbound failure is logged by the existing service; review failed sync activities and reconcile them during the live-store rehearsal. This is not proof of exactly-once remote fulfillment creation.
- Live rate limits, shop-specific shipping rules, multi-location routing and remote GraphQL schema compatibility require the acceptance test above; local mocks cannot certify them.

## References

- https://shopify.dev/docs/api/usage/versioning
- https://shopify.dev/docs/api/admin-graphql/latest/mutations/inventoryActivate
- https://shopify.dev/changelog/posts/expiring-offline-access-tokens-required-for-all-public-apps-as-of-january-1-2027
- https://shopify.dev/docs/apps/build/webhooks/verify-deliveries

## Production rollout and live development-store checks — 16 October 2026

Rails deployed to Heroku `framefox-connect` (v202, commit `87cf576`), including the token/webhook migration and running web + Sidekiq processes. Shopify configuration `onboarding-2026-10` is active. Corrected production `SHOPIFY_HOST` from localhost to `https://connect.framefox.com`.

Installed the production Shopify app on `art-brothers-zvws1dkv.myshopify.com` under George's account. Created six clearly labelled test products, 70 variants, and a free order (#1001 / 6879106039905) with a fictional NZ shipping address. No manufacturing or billing submission was made to the internal NZ/AU production stores.

Verified against live Shopify and the deployed app:

- OAuth installation, saved actual scopes, fulfillment service/location registration, and customer UI return.
- Expiring access and refresh tokens persisted; forced an early refresh on the development store and verified token rotation and future expiry.
- All six products and 70 variants synced, crossing product and variant page boundaries; UI-triggered background sync completed.
- Inventory activation with a SKU, including repeating the same idempotency key.
- Product-create and product-update webhooks received successfully.
- Order import and fulfillment request acceptance via both the service callback and app-config topic.
- Failed deliveries retained and successfully reprocessed after a permission-related fix.
- Exact duplicate order webhook returned HTTP 200 with one local order and one delivery log.
- One of two ordered units fulfilled through `OutboundFulfillmentService`; Shopify confirmed PARTIALLY_FULFILLED, tracking number, and one remaining unit.
- Cancellation of the remaining unit: Shopify confirmed CANCELLATION_ACCEPTED and the local order became cancelled. All 13 test-store webhook logs ended at HTTP 200 with zero pending deliveries.
- NZ and AU payment webhook endpoints accepted correctly signed synthetic payloads and rejected missing/incorrect signatures (six checks). These checks establish application verification behavior, not proof that each Shopify-admin webhook subscription uses the entered secret.

Live testing found and fixed additional issues:

- The order query requested email despite not using it. The Partner Dashboard shows approval from 17 January 2026 for protected customer data, name, phone, and address; email was not selected. Removed email from the query rather than expanding permissions. The failed order and fulfillment deliveries then succeeded.
- Replaced deprecated ShopPlan.displayName, ProductVariant.barcode and ProductVariant.image reads. The barcode connection is retained in metadata, with its first value used for the existing single barcode column.
- Preserved existing variant metadata during sync so pending inventory operation IDs survive reconciliation.

Validation: full suite 121 tests / 594 assertions passed; after removing the unused email field, targeted webhook/onboarding suite 18 tests / 75 assertions passed. Latest live catalog/connection checks succeeded with the replacement fields.

Remaining boundaries and follow-up:

- Shopify requires a SKU to stock a variant at the fulfillment-service location. The test variant was given `FRAMEFOX-TEST-A4`; new merchant catalogs should have SKUs before fulfillment is enabled.
- `LineItem.fulfillableQuantity` replacement is implemented: resync sums paginated fulfillment-order line remaining quantities for OPEN/IN_PROGRESS work. Scheduled, held and terminal orders do not contribute. Missing outstanding lines or API errors abort before local changes; `unfulfilledQuantity` is used only to establish zero outstanding work when a line has no visible fulfillment-order record. Full suite including the country-block notification fix: 130 tests / 636 assertions. A read-only live check of Art Brothers order #1001 returned zero eligible remaining units after cancellation, without the deprecated-field warning.
- Legacy merchant tokens for RK Weston Wear (store 265) and Leden Design (store 298) were migrated on 16 October 2026. Each passed live API checks before migration, after persistence of the new pair, and after a real token refresh. Store 266 (`f3wc1w-bu.myshopify.com`) returned HTTP 402 during preflight; its legacy token was left unchanged pending resolution of the Shopify store/billing restriction. Seven inactive, soft-deleted Shopify records were excluded. Art Brothers already uses expiring tokens. No application deployment was needed for this migration.
- Internal production draft-order costing/shipping, production submission, invoicing, manufacturing and actual carrier delivery were not exercised by this development-store test.
- Uninstall/reinstall, catalog >250 variants, >250 order lines and multi-location split shipments were not live-tested in this run. Existing automated tests cover pagination and split allocation paths.
