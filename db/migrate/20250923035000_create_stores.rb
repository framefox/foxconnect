class CreateStores < ActiveRecord::Migration[8.0]
  def change
    create_table :stores do |t|
      # Basic store information
      t.string :name, null: false
      t.string :platform, null: false, default: 'shopify'

      # Shopify-specific fields (required by ShopifyApp::ShopSessionStorage)
      t.string :shopify_domain, null: false
      t.string :shopify_token
      t.string :access_scopes

      # Additional fields for multi-platform support
      t.json :settings, default: {}
      t.boolean :active, default: true
      t.datetime :last_sync_at

      t.timestamps
    end

    # Indexes for performance
    add_index :stores, :platform
    add_index :stores, :shopify_domain, unique: true
    add_index :stores, [ :platform, :active ]
  end
end
