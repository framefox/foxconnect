class AddProductionPaidAtToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :production_paid_at, :datetime
  end
end
