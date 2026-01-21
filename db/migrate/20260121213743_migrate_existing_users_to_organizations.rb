class MigrateExistingUsersToOrganizations < ActiveRecord::Migration[8.0]
  def up
    # For each existing user without an organization, create one and assign them to it
    execute <<-SQL
      INSERT INTO organizations (name, uid, created_at, updated_at)
      SELECT 
        COALESCE(NULLIF(TRIM(CONCAT(first_name, ' ', last_name)), ''), email) AS name,
        CONCAT('org-', id) AS uid,
        NOW() AS created_at,
        NOW() AS updated_at
      FROM users
      WHERE organization_id IS NULL
    SQL

    # Assign each user to their organization
    execute <<-SQL
      UPDATE users
      SET organization_id = organizations.id
      FROM organizations
      WHERE organizations.uid = CONCAT('org-', users.id)
        AND users.organization_id IS NULL
    SQL

    # Assign each store to its creator's organization
    execute <<-SQL
      UPDATE stores
      SET organization_id = users.organization_id
      FROM users
      WHERE stores.created_by_user_id = users.id
        AND stores.organization_id IS NULL
    SQL
  end

  def down
    # Clear organization assignments
    execute "UPDATE stores SET organization_id = NULL"
    execute "UPDATE users SET organization_id = NULL"
    execute "DELETE FROM organizations WHERE uid LIKE 'org-%'"
  end
end
