class AddMockupSyncResultToProducts < ActiveRecord::Migration[8.0]
  def change
    add_column :products, :mockup_sync_result, :jsonb
  end
end
