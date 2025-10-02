class AddDispatchAndProductionFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :target_dispatch_date, :date
    add_column :orders, :in_production_at, :datetime
  end
end
