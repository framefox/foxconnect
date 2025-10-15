class AddCountryCodeToShopifyCustomers < ActiveRecord::Migration[8.0]
  def change
    # Add country_code column (allowing null temporarily for migration)
    add_column :shopify_customers, :country_code, :string, limit: 2

    # Set all existing records to NZ
    reversible do |dir|
      dir.up do
        execute "UPDATE shopify_customers SET country_code = 'NZ' WHERE country_code IS NULL"
      end
    end

    # Make it not null after setting defaults
    change_column_null :shopify_customers, :country_code, false

    # Add unique index on user_id and country_code
    # A user can only have one shopify_customer per country
    add_index :shopify_customers, [ :user_id, :country_code ], unique: true
  end
end
