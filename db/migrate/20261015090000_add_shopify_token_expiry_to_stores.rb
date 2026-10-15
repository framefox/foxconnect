class AddShopifyTokenExpiryToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :expires_at, :datetime
    add_column :stores, :refresh_token, :text
    add_column :stores, :refresh_token_expires_at, :datetime
    add_column :webhook_logs, :processed_at, :datetime
  end
end
