class AddBundleSlotCountToOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :order_items, :bundle_slot_count, :integer, default: 1, null: false
  end
end
