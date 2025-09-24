class CreateVariantMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :variant_mappings do |t|
      # Association to ProductVariant
      t.references :product_variant, null: false, foreign_key: true

      # Image fields
      t.integer :image_id
      t.string :image_key

      # Frame SKU fields
      t.integer :frame_sku_id
      t.string :frame_sku_code
      t.string :frame_sku_title

      # Crop/positioning coordinates
      t.integer :cx
      t.integer :cy
      t.integer :cw
      t.integer :ch

      # Preview URL
      t.string :preview_url

      t.timestamps
    end

    # Add indexes for performance (product_variant_id index created automatically by t.references)
    add_index :variant_mappings, :image_id
    add_index :variant_mappings, :frame_sku_id
    add_index :variant_mappings, :frame_sku_code
  end
end
