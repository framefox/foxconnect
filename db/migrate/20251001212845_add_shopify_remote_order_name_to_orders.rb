class AddShopifyRemoteOrderNameToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :shopify_remote_order_name, :string
  end
end
