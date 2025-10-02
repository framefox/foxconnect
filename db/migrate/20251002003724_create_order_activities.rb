class CreateOrderActivities < ActiveRecord::Migration[8.0]
  def change
    create_table :order_activities do |t|
      t.references :order, null: false, foreign_key: true
      t.string :activity_type, null: false
      t.string :title, null: false
      t.text :description
      t.json :metadata, default: {}
      t.string :actor_type
      t.integer :actor_id
      t.datetime :occurred_at, null: false

      t.timestamps
    end

    add_index :order_activities, [ :order_id, :occurred_at ]
    add_index :order_activities, [ :activity_type ]
    add_index :order_activities, [ :actor_type, :actor_id ]
  end
end
