class AddFrameSkuCostCentsToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    # Add column as nullable first
    add_column :variant_mappings, :frame_sku_cost_cents, :integer

    # Update existing records to have a default cost (example: $19.99)
    reversible do |dir|
      dir.up do
        execute "UPDATE variant_mappings SET frame_sku_cost_cents = 1999 WHERE frame_sku_cost_cents IS NULL"
      end
    end

    # Now make it non-nullable
    change_column_null :variant_mappings, :frame_sku_cost_cents, false

    add_index :variant_mappings, :frame_sku_cost_cents
  end
end
