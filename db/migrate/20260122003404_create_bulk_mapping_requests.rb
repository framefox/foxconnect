class CreateBulkMappingRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :bulk_mapping_requests do |t|
      t.references :store, null: false, foreign_key: true
      t.string :variant_title, null: false
      t.string :frame_sku_title, null: false
      t.integer :total_count, null: false, default: 0
      t.integer :created_count, null: false, default: 0
      t.integer :skipped_count, null: false, default: 0
      t.string :status, null: false, default: "pending"
      t.text :error_messages

      t.timestamps
    end

    add_index :bulk_mapping_requests, :status
  end
end
