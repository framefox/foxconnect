class ConvertCostColumnsToMoneyRails < ActiveRecord::Migration[8.0]
  def up
    # Orders table: Add new _cents columns
    add_column :orders, :subtotal_price_cents, :integer, default: 0, null: false
    add_column :orders, :total_discounts_cents, :integer, default: 0, null: false
    add_column :orders, :total_shipping_cents, :integer, default: 0, null: false
    add_column :orders, :total_tax_cents, :integer, default: 0, null: false
    add_column :orders, :total_price_cents, :integer, default: 0, null: false

    # Order items table: Add new _cents columns
    add_column :order_items, :price_cents, :integer, default: 0, null: false
    add_column :order_items, :total_cents, :integer, default: 0, null: false
    add_column :order_items, :discount_amount_cents, :integer, default: 0, null: false
    add_column :order_items, :tax_amount_cents, :integer, default: 0, null: false

    # Copy data from decimal columns to cents columns (multiply by 100)
    execute <<-SQL
      UPDATE orders SET
        subtotal_price_cents = (subtotal_price * 100)::integer,
        total_discounts_cents = (total_discounts * 100)::integer,
        total_shipping_cents = (total_shipping * 100)::integer,
        total_tax_cents = (total_tax * 100)::integer,
        total_price_cents = (total_price * 100)::integer
    SQL

    execute <<-SQL
      UPDATE order_items SET
        price_cents = (price * 100)::integer,
        total_cents = (total * 100)::integer,
        discount_amount_cents = (discount_amount * 100)::integer,
        tax_amount_cents = (tax_amount * 100)::integer
    SQL

    # Remove old check constraints
    remove_check_constraint :orders, name: "orders_subtotal_nonneg"
    remove_check_constraint :orders, name: "orders_discounts_nonneg"
    remove_check_constraint :orders, name: "orders_shipping_nonneg"
    remove_check_constraint :orders, name: "orders_tax_nonneg"
    remove_check_constraint :orders, name: "orders_total_nonneg"

    remove_check_constraint :order_items, name: "order_items_price_nonneg"
    remove_check_constraint :order_items, name: "order_items_total_nonneg"
    remove_check_constraint :order_items, name: "order_items_disc_nonneg"
    remove_check_constraint :order_items, name: "order_items_tax_nonneg"

    # Remove old decimal columns
    remove_column :orders, :subtotal_price
    remove_column :orders, :total_discounts
    remove_column :orders, :total_shipping
    remove_column :orders, :total_tax
    remove_column :orders, :total_price

    remove_column :order_items, :price
    remove_column :order_items, :total
    remove_column :order_items, :discount_amount
    remove_column :order_items, :tax_amount

    # Add new check constraints for cents columns
    add_check_constraint :orders, "subtotal_price_cents >= 0", name: "orders_subtotal_nonneg"
    add_check_constraint :orders, "total_discounts_cents >= 0", name: "orders_discounts_nonneg"
    add_check_constraint :orders, "total_shipping_cents >= 0", name: "orders_shipping_nonneg"
    add_check_constraint :orders, "total_tax_cents >= 0", name: "orders_tax_nonneg"
    add_check_constraint :orders, "total_price_cents >= 0", name: "orders_total_nonneg"

    add_check_constraint :order_items, "price_cents >= 0", name: "order_items_price_nonneg"
    add_check_constraint :order_items, "total_cents >= 0", name: "order_items_total_nonneg"
    add_check_constraint :order_items, "discount_amount_cents >= 0", name: "order_items_disc_nonneg"
    add_check_constraint :order_items, "tax_amount_cents >= 0", name: "order_items_tax_nonneg"
  end

  def down
    # Add back old decimal columns
    add_column :orders, :subtotal_price, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :orders, :total_discounts, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :orders, :total_shipping, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :orders, :total_tax, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :orders, :total_price, :decimal, precision: 12, scale: 2, default: "0.0", null: false

    add_column :order_items, :price, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :order_items, :total, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :order_items, :discount_amount, :decimal, precision: 12, scale: 2, default: "0.0", null: false
    add_column :order_items, :tax_amount, :decimal, precision: 12, scale: 2, default: "0.0", null: false

    # Copy data back from cents to decimal (divide by 100)
    execute <<-SQL
      UPDATE orders SET
        subtotal_price = subtotal_price_cents::decimal / 100,
        total_discounts = total_discounts_cents::decimal / 100,
        total_shipping = total_shipping_cents::decimal / 100,
        total_tax = total_tax_cents::decimal / 100,
        total_price = total_price_cents::decimal / 100
    SQL

    execute <<-SQL
      UPDATE order_items SET
        price = price_cents::decimal / 100,
        total = total_cents::decimal / 100,
        discount_amount = discount_amount_cents::decimal / 100,
        tax_amount = tax_amount_cents::decimal / 100
    SQL

    # Remove cents check constraints
    remove_check_constraint :orders, name: "orders_subtotal_nonneg"
    remove_check_constraint :orders, name: "orders_discounts_nonneg"
    remove_check_constraint :orders, name: "orders_shipping_nonneg"
    remove_check_constraint :orders, name: "orders_tax_nonneg"
    remove_check_constraint :orders, name: "orders_total_nonneg"

    remove_check_constraint :order_items, name: "order_items_price_nonneg"
    remove_check_constraint :order_items, name: "order_items_total_nonneg"
    remove_check_constraint :order_items, name: "order_items_disc_nonneg"
    remove_check_constraint :order_items, name: "order_items_tax_nonneg"

    # Remove cents columns
    remove_column :orders, :subtotal_price_cents
    remove_column :orders, :total_discounts_cents
    remove_column :orders, :total_shipping_cents
    remove_column :orders, :total_tax_cents
    remove_column :orders, :total_price_cents

    remove_column :order_items, :price_cents
    remove_column :order_items, :total_cents
    remove_column :order_items, :discount_amount_cents
    remove_column :order_items, :tax_amount_cents

    # Add back old check constraints
    add_check_constraint :orders, "subtotal_price >= 0::numeric", name: "orders_subtotal_nonneg"
    add_check_constraint :orders, "total_discounts >= 0::numeric", name: "orders_discounts_nonneg"
    add_check_constraint :orders, "total_shipping >= 0::numeric", name: "orders_shipping_nonneg"
    add_check_constraint :orders, "total_tax >= 0::numeric", name: "orders_tax_nonneg"
    add_check_constraint :orders, "total_price >= 0::numeric", name: "orders_total_nonneg"

    add_check_constraint :order_items, "price >= 0::numeric", name: "order_items_price_nonneg"
    add_check_constraint :order_items, "total >= 0::numeric", name: "order_items_total_nonneg"
    add_check_constraint :order_items, "discount_amount >= 0::numeric", name: "order_items_disc_nonneg"
    add_check_constraint :order_items, "tax_amount >= 0::numeric", name: "order_items_tax_nonneg"
  end
end
