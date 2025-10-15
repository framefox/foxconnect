class MigrateShopifyCustomersToUsers < ActiveRecord::Migration[8.0]
  def up
    # For each ShopifyCustomer, create a User with their email/first_name/last_name
    # This creates one User per ShopifyCustomer initially (even duplicates)
    # Access columns directly to avoid model delegation issues
    execute <<-SQL
      INSERT INTO users (email, first_name, last_name, created_at, updated_at)
      SELECT email, first_name, last_name, NOW(), NOW()
      FROM shopify_customers
    SQL

    # Link shopify_customers to their new users
    execute <<-SQL
      UPDATE shopify_customers sc
      SET user_id = u.id
      FROM users u
      WHERE sc.email = u.email
      AND sc.user_id IS NULL
      AND u.id IN (
        SELECT id FROM users
        ORDER BY id
        LIMIT (SELECT COUNT(*) FROM shopify_customers)
      )
    SQL

    # Now make user_id non-nullable
    change_column_null :shopify_customers, :user_id, false
  end

  def down
    # Make user_id nullable again
    change_column_null :shopify_customers, :user_id, true

    # Remove user_id from shopify_customers
    execute "UPDATE shopify_customers SET user_id = NULL"
  end
end
