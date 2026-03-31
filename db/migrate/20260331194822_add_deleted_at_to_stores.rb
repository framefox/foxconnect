class AddDeletedAtToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :deleted_at, :datetime
    add_index :stores, :deleted_at
  end
end
