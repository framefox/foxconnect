class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.references :store, null: false, foreign_key: true

      # Cross-platform identifiers
      t.string :external_id, null: false       # platform order id (string for Shopify/Wix/Squarespace)
      t.string :external_number                # platform order number if present
      t.string :name                           # display name (e.g., Shopify "#1001")

      # Customer basics
      t.string :customer_email
      t.string :customer_phone

      # Money + currency
      t.string  :currency, null: false
      t.decimal :subtotal_price,    precision: 12, scale: 2, default: 0, null: false
      t.decimal :total_discounts,   precision: 12, scale: 2, default: 0, null: false
      t.decimal :total_shipping,    precision: 12, scale: 2, default: 0, null: false
      t.decimal :total_tax,         precision: 12, scale: 2, default: 0, null: false
      t.decimal :total_price,       precision: 12, scale: 2, default: 0, null: false

      # Statuses
      t.string :financial_status    # pending, authorized, paid, partially_paid, refunded, voided
      t.string :fulfillment_status  # unfulfilled, partial, fulfilled, restocked, cancelled

      # Lifecycle
      t.datetime :processed_at
      t.datetime :cancelled_at
      t.datetime :closed_at
      t.string   :cancel_reason

      # Misc
      t.json  :tags, default: []
      t.text  :note
      t.json  :raw_payload, default: {}  # full platform payload snapshot

      t.timestamps
    end

    add_index :orders, [ :store_id, :external_id ], unique: true
    add_index :orders, [ :store_id, :processed_at ]

    add_check_constraint :orders, "char_length(currency) = 3", name: "orders_currency_len_3"
    add_check_constraint :orders, "subtotal_price >= 0", name: "orders_subtotal_nonneg"
    add_check_constraint :orders, "total_discounts >= 0", name: "orders_discounts_nonneg"
    add_check_constraint :orders, "total_shipping >= 0", name: "orders_shipping_nonneg"
    add_check_constraint :orders, "total_tax >= 0", name: "orders_tax_nonneg"
    add_check_constraint :orders, "total_price >= 0", name: "orders_total_nonneg"
  end
end
