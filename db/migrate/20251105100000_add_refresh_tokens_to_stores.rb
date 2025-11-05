class AddRefreshTokensToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :squarespace_refresh_token, :string
    add_column :stores, :squarespace_token_expires_at, :datetime
    add_column :stores, :squarespace_refresh_token_expires_at, :datetime
  end
end

