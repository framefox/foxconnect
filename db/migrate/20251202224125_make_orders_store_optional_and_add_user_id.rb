class MakeOrdersStoreOptionalAndAddUserId < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add user_id column
    add_column :orders, :user_id, :bigint
    add_index :orders, :user_id
    
    # Step 2: Backfill user_id from stores for all existing orders
    execute <<-SQL
      UPDATE orders
      SET user_id = stores.user_id
      FROM stores
      WHERE orders.store_id = stores.id
    SQL
    
    # Step 3: Add foreign key to users
    add_foreign_key :orders, :users
    
    # Step 4: Make store_id nullable
    change_column_null :orders, :store_id, true
    
    # Step 5: Remove existing unique index on [store_id, external_id]
    remove_index :orders, name: "index_orders_on_store_id_and_external_id"
    
    # Step 6: Add partial unique index for orders with stores
    add_index :orders, [:store_id, :external_id], 
              unique: true, 
              where: "store_id IS NOT NULL",
              name: "index_orders_on_store_id_and_external_id_not_null"
    
    # Step 7: Add unique index for manual orders (no store)
    add_index :orders, :external_id,
              unique: true,
              where: "store_id IS NULL",
              name: "index_orders_on_external_id_for_manual_orders"
  end
  
  def down
    # Remove the new indexes
    remove_index :orders, name: "index_orders_on_external_id_for_manual_orders"
    remove_index :orders, name: "index_orders_on_store_id_and_external_id_not_null"
    
    # Restore original unique index
    add_index :orders, [:store_id, :external_id], unique: true, name: "index_orders_on_store_id_and_external_id"
    
    # Make store_id required again
    change_column_null :orders, :store_id, false
    
    # Remove foreign key and user_id column
    remove_foreign_key :orders, :users
    remove_index :orders, :user_id
    remove_column :orders, :user_id
  end
end
