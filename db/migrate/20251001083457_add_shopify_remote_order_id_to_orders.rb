class AddShopifyRemoteOrderIdToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :shopify_remote_order_id, :string
    add_index :orders, :shopify_remote_order_id
  end
end
