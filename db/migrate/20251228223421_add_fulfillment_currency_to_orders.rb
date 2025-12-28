class AddFulfillmentCurrencyToOrders < ActiveRecord::Migration[8.0]
  def change
    add_column :orders, :fulfillment_currency, :string, limit: 3
    
    # Add check constraint for 3-character currency code
    add_check_constraint :orders, "char_length(fulfillment_currency::text) = 3", 
                        name: "orders_fulfillment_currency_len_3"
  end
end
