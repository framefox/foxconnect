class AddBundleFieldsToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_reference :variant_mappings, :bundle, null: true, foreign_key: true
    add_reference :variant_mappings, :order_item, null: true, foreign_key: true
    add_column :variant_mappings, :slot_position, :integer
    
    # Add composite unique indexes
    add_index :variant_mappings, [:bundle_id, :slot_position], unique: true, name: 'index_variant_mappings_on_bundle_and_position', where: 'bundle_id IS NOT NULL'
    add_index :variant_mappings, [:order_item_id, :slot_position], unique: true, name: 'index_variant_mappings_on_order_item_and_position', where: 'order_item_id IS NOT NULL'
  end
end
