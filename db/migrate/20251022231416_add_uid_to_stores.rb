class AddUidToStores < ActiveRecord::Migration[8.0]
  def up
    # Add uid column (nullable for now)
    add_column :stores, :uid, :string

    # Generate UIDs for existing stores
    Store.reset_column_information
    Store.find_each do |store|
      store.update_column(:uid, generate_uid)
    end

    # Now make it non-nullable and add unique index
    change_column_null :stores, :uid, false
    add_index :stores, :uid, unique: true
  end

  def down
    remove_index :stores, :uid
    remove_column :stores, :uid
  end

  private

  def generate_uid
    # Generate 8 character alphanumeric UID
    loop do
      uid = SecureRandom.alphanumeric(8).downcase
      break uid unless Store.exists?(uid: uid)
    end
  end
end
