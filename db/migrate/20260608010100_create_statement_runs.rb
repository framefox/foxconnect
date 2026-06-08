class CreateStatementRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :statement_runs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :country_code, limit: 2, null: false
      t.date :period_start_on, null: false
      t.date :period_end_on, null: false
      t.integer :total_amount_cents, default: 0, null: false
      t.string :currency, limit: 3, null: false
      t.string :status, default: "pending", null: false
      t.datetime :sent_at
      t.timestamps
    end

    add_index :statement_runs, [ :company_id, :period_start_on, :period_end_on ], name: "index_statement_runs_on_company_and_period"
    add_index :statement_runs, :status

    create_table :statement_run_line_items do |t|
      t.references :statement_run, null: false, foreign_key: true
      t.references :order, null: false, foreign_key: true, index: { unique: true }
      t.string :shopify_order_id
      t.string :shopify_order_name
      t.string :xero_invoice_id, null: false
      t.string :xero_invoice_number
      t.string :xero_invoice_url
      t.integer :product_amount_cents, default: 0, null: false
      t.integer :shipping_amount_cents, default: 0, null: false
      t.integer :amount_cents, default: 0, null: false
      t.string :currency, limit: 3, null: false
      t.date :invoice_due_date
      t.datetime :invoiced_at
      t.timestamps
    end

    add_index :statement_run_line_items, :xero_invoice_id
  end
end
