class RemoveUniqueConstraintFromVariantMappings < ActiveRecord::Migration[8.0]
  def change
    # Remove the unique constraint on product_variant_id
    remove_index :variant_mappings, :product_variant_id

    # Add it back as a regular (non-unique) index
    add_index :variant_mappings, :product_variant_id
  end
end
