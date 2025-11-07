class CreateBundles < ActiveRecord::Migration[8.0]
  def change
    create_table :bundles do |t|
      t.references :product_variant, null: false, foreign_key: true, index: { unique: true }
      t.integer :slot_count, null: false, default: 1

      t.timestamps
    end
  end
end
