class AddReauthenticationFieldsToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :needs_reauthentication, :boolean, default: false, null: false
    add_column :stores, :reauthentication_flagged_at, :datetime

    add_index :stores, :needs_reauthentication
  end
end

