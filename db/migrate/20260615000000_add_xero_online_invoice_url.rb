class AddXeroOnlineInvoiceUrl < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :xero_online_invoice_url, :string
    add_column :statement_run_line_items, :xero_online_invoice_url, :string
  end
end
