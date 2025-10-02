class AddIsDefaultToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :is_default, :boolean, default: false, null: false
    add_index :variant_mappings, [ :product_variant_id, :is_default ], unique: true, where: "is_default = true"

    # Set existing "default" variant mappings based on current logic
    # (first variant mapping per product variant that's not associated with order items)
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE variant_mappings#{' '}
          SET is_default = true#{' '}
          WHERE id IN (
            SELECT DISTINCT ON (product_variant_id) id
            FROM variant_mappings vm1
            WHERE NOT EXISTS (
              SELECT 1 FROM order_items oi#{' '}
              WHERE oi.variant_mapping_id = vm1.id
            )
            ORDER BY product_variant_id, id
          )
        SQL
      end
    end
  end
end
