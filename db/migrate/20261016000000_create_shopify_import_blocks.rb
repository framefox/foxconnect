class CreateShopifyImportBlocks < ActiveRecord::Migration[8.0]
  def change
    create_table :shopify_import_blocks do |t|
      t.references :store, null: false, foreign_key: { on_delete: :cascade }
      t.string :external_order_id, null: false
      t.datetime :notified_at
      t.timestamps
    end
    add_index :shopify_import_blocks, [ :store_id, :external_order_id ], unique: true
  end
end
