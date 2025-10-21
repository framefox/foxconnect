class RemoveCustomerEmailFromOrders < ActiveRecord::Migration[8.0]
  def change
    remove_column :orders, :customer_email, :string
  end
end
