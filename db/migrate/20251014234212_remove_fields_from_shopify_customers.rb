class RemoveFieldsFromShopifyCustomers < ActiveRecord::Migration[8.0]
  def change
    remove_column :shopify_customers, :email, :string
    remove_column :shopify_customers, :first_name, :string
    remove_column :shopify_customers, :last_name, :string
  end
end
