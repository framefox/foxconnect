class MigrateStoresToUsers < ActiveRecord::Migration[8.0]
  def up
    # Add user_id to stores
    add_reference :stores, :user, foreign_key: true, index: true

    # Migrate data: set user_id from shopify_customers.user_id where stores.shopify_customer_id exists
    execute <<-SQL
      UPDATE stores
      SET user_id = shopify_customers.user_id
      FROM shopify_customers
      WHERE stores.shopify_customer_id = shopify_customers.id
    SQL

    # Remove shopify_customer_id column
    remove_column :stores, :shopify_customer_id
  end

  def down
    # Add shopify_customer_id back
    add_reference :stores, :shopify_customer, foreign_key: true, index: true

    # Note: Cannot fully restore the original shopify_customer_id relationships
    # This would require keeping track of which shopify_customer was originally linked

    # Remove user_id
    remove_column :stores, :user_id
  end
end
