class CreateInvoiceRuns < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_runs do |t|
      t.references :company, null: false, foreign_key: true
      t.string :country_code, limit: 2, null: false
      t.string :xero_invoice_id
      t.string :xero_invoice_number
      t.string :xero_invoice_url
      t.integer :total_amount_cents, default: 0, null: false
      t.string :currency, limit: 3, null: false
      t.string :status, default: "draft", null: false
      t.date :invoice_date, null: false
      t.timestamps
    end

    add_index :invoice_runs, :xero_invoice_id, unique: true, where: "xero_invoice_id IS NOT NULL"
    add_index :invoice_runs, :status
  end
end
