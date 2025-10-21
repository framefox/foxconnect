class AddProductsLastUpdatedAtToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :products_last_updated_at, :datetime
    add_index :stores, :products_last_updated_at
  end
end
