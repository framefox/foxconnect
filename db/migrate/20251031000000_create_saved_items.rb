class CreateSavedItems < ActiveRecord::Migration[8.0]
  def change
    create_table :saved_items do |t|
      t.references :user, null: false, foreign_key: true
      t.integer :frame_sku_id, null: false

      t.timestamps
    end

    add_index :saved_items, [ :user_id, :frame_sku_id ], unique: true
  end
end

