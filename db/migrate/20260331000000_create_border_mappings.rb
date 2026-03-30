class CreateBorderMappings < ActiveRecord::Migration[8.0]
  def change
    create_table :border_mappings do |t|
      t.references :store, null: false, foreign_key: true
      t.integer :paper_type_id, null: false
      t.string :paper_type_name
      t.integer :border_width_mm, null: false, default: 0
      t.timestamps
    end

    add_index :border_mappings, [ :store_id, :paper_type_id ], unique: true
  end
end
