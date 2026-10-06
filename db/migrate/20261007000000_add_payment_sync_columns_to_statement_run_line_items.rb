class AddPaymentSyncColumnsToStatementRunLineItems < ActiveRecord::Migration[8.0]
  def change
    add_column :statement_run_line_items, :xero_paid_at, :datetime
    add_column :statement_run_line_items, :shopify_marked_paid_at, :datetime
    add_column :statement_run_line_items, :shopify_paid_error, :text
  end
end
