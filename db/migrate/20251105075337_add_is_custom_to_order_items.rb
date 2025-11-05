class AddIsCustomToOrderItems < ActiveRecord::Migration[8.0]
  def change
    add_column :order_items, :is_custom, :boolean, default: false, null: false
  end
end
