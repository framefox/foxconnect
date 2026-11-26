class AddCatalogueReconciliationIndexes < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :product_variants, [ :product_id, :last_seen_in_source_at, :id ],
      include: [ :created_at ], where: "removed_from_source_at IS NULL",
      name: "index_present_variants_for_reconciliation", algorithm: :concurrently
    add_index :products, [ :store_id, :last_seen_in_source_at, :id ],
      include: [ :created_at ], where: "removed_from_source_at IS NULL",
      name: "index_present_products_for_reconciliation", algorithm: :concurrently
  end
end
