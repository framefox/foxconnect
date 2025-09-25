class AddImageDimensionsToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :image_width, :integer
    add_column :variant_mappings, :image_height, :integer
  end
end
