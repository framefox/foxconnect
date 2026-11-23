class ScopeBundleMappingSlotsByCountry < ActiveRecord::Migration[8.0]
  def up
    remove_index :variant_mappings, name: "index_variant_mappings_on_bundle_and_position"
    add_index :variant_mappings, [:bundle_id, :slot_position, :country_code], unique: true,
      name: "index_variant_mappings_on_bundle_slot_country", where: "bundle_id IS NOT NULL"
  end

  def down
    # Refuse rollback if regional mappings now share a slot; never discard mappings.
    add_index :variant_mappings, [:bundle_id, :slot_position], unique: true,
      name: "index_variant_mappings_on_bundle_and_position", where: "bundle_id IS NOT NULL"
    remove_index :variant_mappings, name: "index_variant_mappings_on_bundle_slot_country"
  end
end
