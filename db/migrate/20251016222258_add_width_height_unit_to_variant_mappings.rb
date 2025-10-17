class AddWidthHeightUnitToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :width, :decimal, precision: 6, scale: 2
    add_column :variant_mappings, :height, :decimal, precision: 6, scale: 2
    add_column :variant_mappings, :unit, :string
  end
end
