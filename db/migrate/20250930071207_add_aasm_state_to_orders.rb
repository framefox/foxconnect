class AddAasmStateToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :aasm_state, :string, default: "draft", null: false
    add_index :orders, :aasm_state
  end
end
