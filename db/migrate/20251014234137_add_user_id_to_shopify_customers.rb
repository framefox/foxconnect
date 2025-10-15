class AddUserIdToShopifyCustomers < ActiveRecord::Migration[8.0]
  def change
    add_reference :shopify_customers, :user, null: true, foreign_key: true, index: true
  end
end
