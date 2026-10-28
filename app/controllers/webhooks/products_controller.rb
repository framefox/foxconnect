module Webhooks
  class ProductsController < ApplicationController
    include ShopifyWebhookVerification

    before_action :find_store

    def create
      schedule_catalog_sync
      head :ok
    end

    def update
      schedule_catalog_sync
      head :ok
    end

    def destroy
      return if performed? || @store.nil?

      external_id = request_payload["id"]
      ShopifyProductRemovalJob.perform_later(@store.id, external_id.to_s) if external_id.present?
      schedule_catalog_sync
      head :ok
    end

    private

    def find_store
      @store = find_store_by_webhook_headers
    end

    def schedule_catalog_sync
      return if performed? || @store.nil?

      Shopify::CatalogSyncStamp.mark!(@store)
    end

    def request_payload
      JSON.parse(request.raw_post)
    rescue JSON::ParserError
      {}
    end
  end
end
