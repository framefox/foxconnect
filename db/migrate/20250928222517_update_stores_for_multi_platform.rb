class UpdateStoresForMultiPlatform < ActiveRecord::Migration[8.0]
  def change
    # Make shopify_domain optional since other platforms won't have this
    change_column_null :stores, :shopify_domain, true

    # Add columns for other platforms (we'll add these as needed)
    # For now, just make the existing structure more flexible

    # Update the unique index to allow null shopify_domains
    remove_index :stores, :shopify_domain
    add_index :stores, :shopify_domain, unique: true, where: "shopify_domain IS NOT NULL"

    # Add platform-specific columns that might be needed in the future
    add_column :stores, :wix_site_id, :string
    add_column :stores, :wix_token, :string
    add_column :stores, :squarespace_domain, :string
    add_column :stores, :squarespace_token, :string

    # Add indexes for the new platform identifiers
    add_index :stores, :wix_site_id, unique: true, where: "wix_site_id IS NOT NULL"
    add_index :stores, :squarespace_domain, unique: true, where: "squarespace_domain IS NOT NULL"
  end
end
