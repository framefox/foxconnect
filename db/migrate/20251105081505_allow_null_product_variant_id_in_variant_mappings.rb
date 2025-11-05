class AllowNullProductVariantIdInVariantMappings < ActiveRecord::Migration[8.0]
  def change
    change_column_null :variant_mappings, :product_variant_id, true
  end
end
