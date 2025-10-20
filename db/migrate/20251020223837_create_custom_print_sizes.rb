class CreateCustomPrintSizes < ActiveRecord::Migration[8.0]
  def change
    create_table :custom_print_sizes do |t|
      t.references :user, null: false, foreign_key: true, index: true
      t.decimal :long, precision: 6, scale: 2, null: false
      t.decimal :short, precision: 6, scale: 2, null: false
      t.string :unit, null: false
      t.integer :frame_sku_size_id, null: false
      t.string :frame_sku_size_description, null: false

      t.timestamps
    end
  end
end
