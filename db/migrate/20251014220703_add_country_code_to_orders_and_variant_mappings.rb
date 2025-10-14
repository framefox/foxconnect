class AddCountryCodeToOrdersAndVariantMappings < ActiveRecord::Migration[8.0]
  def up
    # Add country_code to orders table
    add_column :orders, :country_code, :string, limit: 2
    add_index :orders, :country_code

    # Add country_code to variant_mappings table
    add_column :variant_mappings, :country_code, :string, limit: 2, null: false, default: "NZ"
    add_index :variant_mappings, [ :product_variant_id, :country_code ]

    # Remove old unique constraint on is_default (if it exists)
    remove_index :variant_mappings, name: "index_variant_mappings_on_product_variant_id_and_is_default", if_exists: true

    # Add new unique constraint: one default per country per variant
    add_index :variant_mappings, [ :product_variant_id, :country_code, :is_default ],
              unique: true,
              where: "(is_default = true)",
              name: "idx_variant_mappings_default_per_country"
  end

  def down
    # Remove new constraint
    remove_index :variant_mappings, name: "idx_variant_mappings_default_per_country", if_exists: true

    # Restore old constraint
    add_index :variant_mappings, [ :product_variant_id, :is_default ],
              unique: true,
              where: "(is_default = true)",
              name: "index_variant_mappings_on_product_variant_id_and_is_default"

    # Remove country_code columns
    remove_index :variant_mappings, [ :product_variant_id, :country_code ], if_exists: true
    remove_column :variant_mappings, :country_code

    remove_index :orders, :country_code, if_exists: true
    remove_column :orders, :country_code
  end
end
