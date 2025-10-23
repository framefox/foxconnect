class AddUidToOrders < ActiveRecord::Migration[8.0]
  def up
    # Add uid column (nullable for now)
    add_column :orders, :uid, :string

    # Generate UIDs for existing orders
    Order.reset_column_information
    Order.find_each do |order|
      order.update_column(:uid, generate_uid)
    end

    # Now make it non-nullable and add unique index
    change_column_null :orders, :uid, false
    add_index :orders, :uid, unique: true
  end

  def down
    remove_index :orders, :uid
    remove_column :orders, :uid
  end

  private

  def generate_uid
    # Generate 10 character alphanumeric UID
    loop do
      uid = SecureRandom.alphanumeric(10).downcase
      break uid unless Order.exists?(uid: uid)
    end
  end
end
