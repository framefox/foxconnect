class AddSourceReconciliationFieldsToProductsAndVariants < ActiveRecord::Migration[8.0]
  def change
    change_table :products, bulk: true do |t|
      t.datetime :removed_from_source_at
      t.datetime :last_seen_in_source_at
      t.index :removed_from_source_at
    end

    change_table :product_variants, bulk: true do |t|
      t.datetime :removed_from_source_at
      t.datetime :last_seen_in_source_at
      t.index :removed_from_source_at
    end
  end
end
