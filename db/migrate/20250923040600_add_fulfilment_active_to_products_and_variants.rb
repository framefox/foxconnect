class AddFulfilmentActiveToProductsAndVariants < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :fulfilment_active, :boolean, default: false, null: false
    add_column :product_variants, :fulfilment_active, :boolean, default: false, null: false

    add_index :products, :fulfilment_active
    add_index :product_variants, :fulfilment_active
  end
end
