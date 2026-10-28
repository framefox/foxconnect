class AddProductSyncStateToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :product_sync_state, :jsonb, default: {}, null: false
  end
end
