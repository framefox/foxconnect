class CreateFulfillmentLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :fulfillment_line_items do |t|
      t.references :fulfillment, null: false, foreign_key: true, index: true
      t.references :order_item, null: false, foreign_key: true, index: true
      t.integer :quantity, null: false

      t.timestamps
    end

    add_index :fulfillment_line_items, [:fulfillment_id, :order_item_id], unique: true, name: 'index_fulfillment_line_items_on_fulfillment_and_order_item'
  end
end
