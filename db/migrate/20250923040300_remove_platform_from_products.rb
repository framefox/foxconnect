class RemovePlatformFromProducts < ActiveRecord::Migration[8.0]
  def change
    # Remove the platform column since it's now delegated from store
    remove_column :products, :platform, :string
  end
end
