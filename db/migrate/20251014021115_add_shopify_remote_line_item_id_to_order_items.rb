class AddShopifyRemoteLineItemIdToOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :order_items, :shopify_remote_line_item_id, :string
    add_index :order_items, :shopify_remote_line_item_id
  end
end
