class AddXeroInvoiceFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :xero_invoice_id, :string
    add_column :orders, :xero_invoice_number, :string
    add_column :orders, :xero_invoice_url, :string
    add_column :orders, :xero_invoice_due_date, :date
    add_column :orders, :xero_invoiced_at, :datetime
    add_column :orders, :xero_invoice_error, :text

    add_index :orders, :xero_invoice_id, unique: true, where: "xero_invoice_id IS NOT NULL"
    add_index :orders, :xero_invoiced_at
  end
end
