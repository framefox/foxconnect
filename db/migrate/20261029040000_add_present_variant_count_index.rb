class AddPresentVariantCountIndex < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    # Present variants are almost every row, so a store-wide count was scanning
    # the whole table. This index is small enough to count from directly.
    add_index :product_variants, [ :product_id, :fulfilment_active ],
      where: "removed_from_source_at IS NULL",
      name: "index_product_variants_present_on_product_and_fulfilment",
      algorithm: :concurrently
  end
end
