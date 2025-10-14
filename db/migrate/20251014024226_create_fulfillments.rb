class CreateFulfillments < ActiveRecord::Migration[8.0]
  def change
    create_table :fulfillments do |t|
      t.references :order, null: false, foreign_key: true, index: true
      t.string :shopify_fulfillment_id
      t.string :status, null: false
      t.string :tracking_company
      t.string :tracking_number
      t.string :tracking_url
      t.string :location_name
      t.string :shopify_location_id
      t.string :shipment_status
      t.datetime :fulfilled_at

      t.timestamps
    end

    add_index :fulfillments, :shopify_fulfillment_id, unique: true
  end
end
