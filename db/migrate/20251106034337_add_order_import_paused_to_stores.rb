class AddOrderImportPausedToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :order_import_paused, :boolean, default: true, null: false
  end
end
