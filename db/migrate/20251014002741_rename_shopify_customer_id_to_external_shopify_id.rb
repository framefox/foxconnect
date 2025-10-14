class RenameShopifyCustomerIdToExternalShopifyId < ActiveRecord::Migration[8.0]
  def change
    # Rename the column on shopify_customers table
    rename_column :shopify_customers, :shopify_customer_id, :external_shopify_id

    # Rename the index if it exists
    if index_exists?(:shopify_customers, :shopify_customer_id, name: :index_shopify_customers_on_shopify_customer_id)
      rename_index :shopify_customers, :index_shopify_customers_on_shopify_customer_id, :index_shopify_customers_on_external_shopify_id
    end
  end
end
