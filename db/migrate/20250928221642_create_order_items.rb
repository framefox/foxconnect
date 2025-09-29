class CreateOrderItems < ActiveRecord::Migration[8.0]
  def change
    create_table :order_items do |t|
      t.references :order, null: false, foreign_key: true

      # Cross-platform line identifiers
      t.string :external_line_id
      t.string :external_product_id
      t.string :external_variant_id

      # Denormalized display data
      t.string  :title
      t.string  :sku
      t.string  :variant_title

      # Quantities and money
      t.integer :quantity, null: false, default: 1
      t.decimal :price,     precision: 12, scale: 2, null: false, default: 0  # unit price
      t.decimal :total,     precision: 12, scale: 2, null: false, default: 0  # line total (after discounts)
      t.decimal :discount_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :tax_amount,      precision: 12, scale: 2, null: false, default: 0
      t.boolean :taxes_included, default: false
      t.boolean :requires_shipping, default: true

      # Links into catalog/mapping (optional until resolved)
      t.references :product_variant, foreign_key: true
      t.references :variant_mapping, foreign_key: true

      t.json :raw_payload, default: {}

      t.timestamps
    end

    add_index :order_items, :external_variant_id
    add_index :order_items, :external_product_id

    add_check_constraint :order_items, "quantity > 0", name: "order_items_qty_positive"
    add_check_constraint :order_items, "price >= 0", name: "order_items_price_nonneg"
    add_check_constraint :order_items, "total >= 0", name: "order_items_total_nonneg"
    add_check_constraint :order_items, "discount_amount >= 0", name: "order_items_disc_nonneg"
    add_check_constraint :order_items, "tax_amount >= 0", name: "order_items_tax_nonneg"
  end
end
