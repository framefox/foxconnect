module Connections
  class BulkFulfilmentSettingsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_store

    def enable
      updated_count = bulk_update_fulfilment_status(true)

      redirect_to connections_store_path(@store),
                  notice: "Fulfilment enabled for #{updated_count[:products]} products and #{updated_count[:variants]} variants."
    end

    def disable
      updated_count = bulk_update_fulfilment_status(false)

      redirect_to connections_store_path(@store),
                  notice: "Fulfilment disabled for #{updated_count[:products]} products and #{updated_count[:variants]} variants."
    end

    private

    def set_store
      @store = current_user.stores.find_by!(uid: params[:store_uid])
    end

    def bulk_update_fulfilment_status(status)
      # Use update_all for better performance with large datasets
      products_updated = @store.products.update_all(fulfilment_active: status)
      variants_updated = @store.product_variants.update_all(fulfilment_active: status)

      { products: products_updated, variants: variants_updated }
    end
  end
end
