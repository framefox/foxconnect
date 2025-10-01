class AddFrameSkuDescriptionAndImageFilenameToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :frame_sku_description, :text
    add_column :variant_mappings, :image_filename, :string
  end
end
