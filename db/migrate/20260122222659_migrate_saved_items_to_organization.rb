class MigrateSavedItemsToOrganization < ActiveRecord::Migration[8.0]
  def up
    # Step 1: Add organization_id column (nullable initially)
    add_reference :saved_items, :organization, foreign_key: true

    # Step 2: Populate organization_id from each user's organization
    execute <<-SQL
      UPDATE saved_items
      SET organization_id = users.organization_id
      FROM users
      WHERE saved_items.user_id = users.id
    SQL

    # Step 3: Delete any saved_items where user has no organization
    execute <<-SQL
      DELETE FROM saved_items WHERE organization_id IS NULL
    SQL

    # Step 4: Delete duplicates within same organization, keeping the oldest (lowest id)
    execute <<-SQL
      DELETE FROM saved_items
      WHERE id NOT IN (
        SELECT MIN(id)
        FROM saved_items
        GROUP BY organization_id, frame_sku_id
      )
    SQL

    # Step 5: Remove the old user_id column and its indexes/foreign key
    remove_foreign_key :saved_items, :users
    remove_index :saved_items, name: "index_saved_items_on_user_id_and_frame_sku_id"
    remove_index :saved_items, name: "index_saved_items_on_user_id"
    remove_column :saved_items, :user_id

    # Step 6: Make organization_id not null and add unique index
    change_column_null :saved_items, :organization_id, false
    add_index :saved_items, [ :organization_id, :frame_sku_id ], unique: true
  end

  def down
    # Step 1: Remove unique index and make organization_id nullable
    remove_index :saved_items, [ :organization_id, :frame_sku_id ]
    change_column_null :saved_items, :organization_id, true

    # Step 2: Add user_id column back
    add_reference :saved_items, :user, foreign_key: true

    # Step 3: Populate user_id from first user of each organization
    # Note: This is a best-effort reverse - data may not match original exactly
    execute <<-SQL
      UPDATE saved_items
      SET user_id = (
        SELECT users.id
        FROM users
        WHERE users.organization_id = saved_items.organization_id
        ORDER BY users.id
        LIMIT 1
      )
    SQL

    # Step 4: Remove saved_items without a user
    execute <<-SQL
      DELETE FROM saved_items WHERE user_id IS NULL
    SQL

    # Step 5: Make user_id not null and add indexes
    change_column_null :saved_items, :user_id, false
    add_index :saved_items, :user_id
    add_index :saved_items, [ :user_id, :frame_sku_id ], unique: true

    # Step 6: Remove organization_id
    remove_reference :saved_items, :organization
  end
end
