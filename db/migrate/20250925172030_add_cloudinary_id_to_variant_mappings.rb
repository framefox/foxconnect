class AddCloudinaryIdToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :cloudinary_id, :string
  end
end
