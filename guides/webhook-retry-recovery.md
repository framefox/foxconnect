# Webhook retry and recovery

Merchant order imports and fulfillment notifications use `WebhookLog` as the durable source of delivery state. Production-store fulfillment callbacks and other job classes are unchanged.

- A delivery has one current Active Job ID. Older queued copies are no-ops.
- The 10-minute recovery task schedules due retries. Rails and Sidekiq do not independently retry these delivery jobs.
- A maximum of five processing attempts survives job replacement and process restarts. Temporary errors wait exponentially (2, 4, 8, 16 minutes), rounded up to the next recovery pass.
- A 30-minute lease recovers enqueue failures and crashed workers. Recovery checks the Redis queue before replacing a lease and skips deliveries locked by a running worker.
- A confirmed Shopify null-order response goes immediately to `needs_review`. Invalid payloads and exhausted attempts also stop for review. A malformed API response remains retryable. Missing orders are never automatically assumed fulfilled.
- Admin → Webhook Logs → Needs review shows the order ID, event age, attempts and error. Retire requires a reason and records the administrator and time, preserving the original error. Retired events are acknowledged on redelivery and old queued jobs cannot execute them. Review and retirement records are excluded from routine log cleanup.

Deploy migration `20261026040000` before the updated worker starts. It is additive and compatible with the old code. It also preserves the earlier operator retirements as explicitly retired records. Deploy both web and worker from the same commit. An application rollback leaves the added fields intact, but old workers do not honor `needs_review`; do not roll back while unresolved reviewed events exist without first stopping/reconciling those workers.

The lease prevents simultaneous execution, but external operations still need their existing idempotency checks: a process can die after an API side effect and before committing success locally. Do not blanket replay reviewed events. Investigate access/availability and reconcile Shopify before deliberately re-enqueueing work.
