class AddBorderWidthMmToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :border_width_mm, :integer, default: 0, null: false
  end
end
