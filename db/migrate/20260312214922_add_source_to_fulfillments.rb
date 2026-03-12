class AddSourceToFulfillments < ActiveRecord::Migration[8.0]
  def change
    add_column :fulfillments, :source, :string, null: false, default: "production_webhook"
    add_index :fulfillments, :source
  end
end
