class CreateProductVariants < ActiveRecord::Migration[8.0]
  def change
    create_table :product_variants do |t|
      # Association
      t.references :product, null: false, foreign_key: true

      # Platform identification
      t.bigint :external_variant_id, null: false # Numeric platform variant ID (789012)

      # Core identification
      t.string :title, null: false # "Red / Large"
      t.string :sku # Platform SKU
      t.string :barcode
      t.integer :position, default: 1

      # Pricing (where the actual prices live)
      t.decimal :price, precision: 10, scale: 2, null: false
      t.decimal :compare_at_price, precision: 10, scale: 2

      # Availability
      t.boolean :available_for_sale, default: true

      # Physical properties (basic shipping info)
      t.decimal :weight, precision: 8, scale: 3
      t.string :weight_unit, default: 'kg'
      t.boolean :requires_shipping, default: true

      # Option selections (how this variant differs from the product)
      t.json :selected_options, default: [] # [{"name": "Color", "value": "Red"}, ...]

      # Media
      t.string :image_url

      # Metadata for extensibility
      t.json :metadata, default: {}

      t.timestamps
    end

    # Indexes for performance
    add_index :product_variants, [ :product_id, :external_variant_id ], unique: true
    add_index :product_variants, :sku
    add_index :product_variants, :barcode
    add_index :product_variants, :position
    add_index :product_variants, :available_for_sale
    add_index :product_variants, [ :product_id, :position ]
  end
end
