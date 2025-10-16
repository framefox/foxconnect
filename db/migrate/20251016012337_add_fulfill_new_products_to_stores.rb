class AddFulfillNewProductsToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :fulfill_new_products, :boolean, default: false
  end
end
