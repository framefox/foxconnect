class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      # Platform identification
      t.bigint :external_id, null: false # Numeric platform ID (123456)
      t.string :platform, null: false # 'shopify', 'squarespace', 'wix'

      # Core identification
      t.string :title, null: false
      t.text :description
      t.text :description_html
      t.string :handle, null: false

      # Categorization
      t.string :product_type
      t.string :vendor
      t.json :tags, default: []

      # Product structure
      t.json :options, default: [] # [{name: "Color", values: ["Red", "Blue"]}]

      # Media
      t.json :images, default: []
      t.string :featured_image_url

      # Status
      t.string :status, default: 'draft' # draft, active, archived
      t.datetime :published_at

      # Metadata for extensibility
      t.json :metadata, default: {}

      t.timestamps
    end

    # Indexes for performance
    add_index :products, [ :platform, :external_id ], unique: true # Unique per platform
    add_index :products, :handle
    add_index :products, :title
    add_index :products, :product_type
    add_index :products, :vendor
    add_index :products, :status
    add_index :products, :platform
  end
end
