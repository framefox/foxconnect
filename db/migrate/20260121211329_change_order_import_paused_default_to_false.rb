class ChangeOrderImportPausedDefaultToFalse < ActiveRecord::Migration[8.0]
  def change
    change_column_default :stores, :order_import_paused, from: true, to: false
  end
end
