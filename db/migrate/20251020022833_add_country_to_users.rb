class AddCountryToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :country, :string
  end
end
