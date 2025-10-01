class RenameShopifyDraftOrderIdToShopifyRemoteDraftOrderId < ActiveRecord::Migration[8.0]
  def change
    rename_column :orders, :shopify_draft_order_id, :shopify_remote_draft_order_id

    # Remove old index and add new one with correct name
    if index_exists?(:orders, :shopify_draft_order_id)
      remove_index :orders, :shopify_draft_order_id
    end

    unless index_exists?(:orders, :shopify_remote_draft_order_id)
      add_index :orders, :shopify_remote_draft_order_id
    end
  end
end
