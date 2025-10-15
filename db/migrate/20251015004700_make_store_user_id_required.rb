class MakeStoreUserIdRequired < ActiveRecord::Migration[8.0]
  def change
    # Make user_id required on stores table
    change_column_null :stores, :user_id, false
  end
end
