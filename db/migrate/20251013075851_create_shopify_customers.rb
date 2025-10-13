class CreateShopifyCustomers < ActiveRecord::Migration[8.0]
  def change
    create_table :shopify_customers do |t|
      t.bigint :shopify_customer_id, null: false
      t.string :first_name
      t.string :last_name
      t.string :email, null: false

      t.timestamps
    end
    add_index :shopify_customers, :shopify_customer_id, unique: true
    add_index :shopify_customers, :email
  end
end
