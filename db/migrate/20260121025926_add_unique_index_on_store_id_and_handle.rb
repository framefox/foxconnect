class AddUniqueIndexOnStoreIdAndHandle < ActiveRecord::Migration[8.0]
  def change
    # Remove the existing non-unique index on handle
    remove_index :products, :handle, if_exists: true

    # Add a unique composite index on store_id and handle
    # This enforces that handles are unique within each store, but the same handle
    # can exist across different stores
    add_index :products, [:store_id, :handle], unique: true, name: "index_products_on_store_id_and_handle_unique"
  end
end
