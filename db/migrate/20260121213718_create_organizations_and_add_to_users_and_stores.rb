class CreateOrganizationsAndAddToUsersAndStores < ActiveRecord::Migration[8.0]
  def change
    # Create organizations table
    create_table :organizations do |t|
      t.string :name, null: false
      t.string :uid, null: false

      t.timestamps
    end

    add_index :organizations, :uid, unique: true

    # Add organization_id to users
    add_reference :users, :organization, foreign_key: true

    # Add organization_id to stores and rename user_id to created_by_user_id
    add_reference :stores, :organization, foreign_key: true
    rename_column :stores, :user_id, :created_by_user_id

    # Update foreign key for stores (rename constraint)
    remove_foreign_key :stores, column: :created_by_user_id
    add_foreign_key :stores, :users, column: :created_by_user_id
  end
end
