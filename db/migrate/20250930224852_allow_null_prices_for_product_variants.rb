class AllowNullPricesForProductVariants < ActiveRecord::Migration[8.0]
  def change
    change_column_null :product_variants, :price, true
  end
end
