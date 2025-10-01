class RenameDimensionColumnsInVariantMappings < ActiveRecord::Migration[8.0]
  def change
    rename_column :variant_mappings, :long, :frame_sku_long
    rename_column :variant_mappings, :short, :frame_sku_short
    rename_column :variant_mappings, :unit, :frame_sku_unit
  end
end
