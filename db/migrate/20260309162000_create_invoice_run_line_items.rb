class CreateInvoiceRunLineItems < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_run_line_items do |t|
      t.references :invoice_run, null: false, foreign_key: true
      t.string :shopify_order_id, null: false
      t.string :shopify_order_name, null: false
      t.integer :amount_cents, default: 0, null: false
      t.string :currency, limit: 3, null: false
      t.timestamps
    end

    add_index :invoice_run_line_items, :shopify_order_id, unique: true
  end
end
