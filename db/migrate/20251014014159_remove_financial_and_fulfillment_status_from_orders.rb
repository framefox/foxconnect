class RemoveFinancialAndFulfillmentStatusFromOrders < ActiveRecord::Migration[8.0]
  def change
    remove_column :orders, :financial_status, :string
    remove_column :orders, :fulfillment_status, :string
  end
end
