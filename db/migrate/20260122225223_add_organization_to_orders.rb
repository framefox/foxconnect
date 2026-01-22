class AddOrganizationToOrders < ActiveRecord::Migration[8.0]
  def up
    # Add the column as nullable first
    add_reference :orders, :organization, null: true, foreign_key: true

    # Backfill existing orders with organization_id
    # For imported orders: use store's organization_id
    # For manual orders: use user's organization_id
    execute <<-SQL
      UPDATE orders
      SET organization_id = COALESCE(
        (SELECT stores.organization_id FROM stores WHERE stores.id = orders.store_id),
        (SELECT users.organization_id FROM users WHERE users.id = orders.user_id)
      )
      WHERE organization_id IS NULL
    SQL
  end

  def down
    remove_reference :orders, :organization
  end
end
