class AddUniqueIndexToVariantMappingsProductVariantId < ActiveRecord::Migration[8.0]
  def change
    # Remove existing non-unique index
    remove_index :variant_mappings, :product_variant_id

    # Add unique index to enforce one-to-one relationship
    add_index :variant_mappings, :product_variant_id, unique: true
  end
end
