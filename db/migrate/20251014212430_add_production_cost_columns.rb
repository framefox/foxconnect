class AddProductionCostColumns < ActiveRecord::Migration[8.0]
  def change
    # Add production cost columns to orders table
    add_column :orders, :production_subtotal_cents, :integer, default: 0, null: false
    add_column :orders, :production_shipping_cents, :integer, default: 0, null: false
    add_column :orders, :production_total_cents, :integer, default: 0, null: false

    # Add production cost column to order_items table
    add_column :order_items, :production_cost_cents, :integer, default: 0, null: false

    # Add check constraints to ensure non-negative values
    add_check_constraint :orders, "production_subtotal_cents >= 0", name: "orders_production_subtotal_nonneg"
    add_check_constraint :orders, "production_shipping_cents >= 0", name: "orders_production_shipping_nonneg"
    add_check_constraint :orders, "production_total_cents >= 0", name: "orders_production_total_nonneg"
    add_check_constraint :order_items, "production_cost_cents >= 0", name: "order_items_production_cost_nonneg"
  end
end
