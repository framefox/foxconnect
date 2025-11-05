class ChangeExternalVariantIdToString < ActiveRecord::Migration[8.0]
  def up
    # Change external_id from bigint to string for Product (Squarespace uses string IDs)
    change_column :products, :external_id, :string, null: false
    
    # Change external_variant_id from bigint to string for ProductVariant (Squarespace uses UUIDs)
    change_column :product_variants, :external_variant_id, :string, null: false
  end

  def down
    # Revert back to bigint
    change_column :products, :external_id, :bigint, null: false
    change_column :product_variants, :external_variant_id, :bigint, null: false
  end
end

