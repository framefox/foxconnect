class ShopifyProductSyncJob < ApplicationJob
  queue_as :default

  # The original one-argument signature remains valid for already queued jobs.
  def perform(store, run_id: nil, step: nil)
    continuation = nil
    store.with_lock do
      return unless store.platform == "shopify" && store.shopify_token.present? && store.active?

      state = store.product_sync_state
      if run_id
        return unless state["run_id"] == run_id && state["status"] == "running"
        if state["step"] != step
          # A retry may arrive after the previous batch committed but enqueue
          # failed. Re-dispatch the current checkpoint without replaying writes.
          continuation = { run_id: state.fetch("run_id"), step: state.fetch("step") }
          next
        end
      elsif state["status"] == "running"
        # Resume existing progress rather than starting an overlapping scan.
        continuation = { run_id: state.fetch("run_id"), step: state.fetch("step") }
        next
      else
        state = { "run_id" => SecureRandom.uuid, "step" => 0, "status" => "running",
                  "phase" => "products", "started_at" => Time.current.iso8601(6) }
      end

      service = ShopifyProductSyncService.new(store)
      synced_at = Time.iso8601(state.fetch("started_at"))
      if state["phase"] == "products"
        result = service.sync_product_batch(after_cursor: state["cursor"], synced_at: synced_at)
        if !result[:full_reconciliation_completed]
          state["status"] = "incomplete"
          Rails.logger.warn "Product sync incomplete for store #{store.id}; archival skipped"
        elsif result[:next_cursor]
          state["cursor"] = result[:next_cursor]
        else
          state["phase"] = "archive"
        end
      elsif !service.reconcile_product_batch(synced_at: synced_at)
        state["status"] = "completed"
        store.last_sync_at = Time.current
        Rails.logger.info "Product sync completed for store #{store.id}"
      end

      state["step"] += 1
      store.update!(product_sync_state: state)
      if state["status"] == "running"
        continuation = { run_id: state.fetch("run_id"), step: state.fetch("step") }
      end
    end
    # Enqueue after commit: retries/duplicate deliveries are guarded by the
    # persisted step. A later scheduled request also resumes stranded progress.
    self.class.perform_later(store, **continuation) if continuation
  rescue ShopifyIntegration::InactiveStoreError
    Rails.logger.warn "Product sync skipped for inactive store #{store.id}"
  end
end
