class AddBundlesEnabledToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :bundles_enabled, :boolean, default: false, null: false
  end
end

