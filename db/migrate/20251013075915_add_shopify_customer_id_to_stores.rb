class AddShopifyCustomerIdToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :shopify_customer_id, :bigint
    add_index :stores, :shopify_customer_id
  end
end
