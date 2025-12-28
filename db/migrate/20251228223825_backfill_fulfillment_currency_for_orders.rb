class BackfillFulfillmentCurrencyForOrders < ActiveRecord::Migration[8.0]
  def up
    # Backfill fulfillment_currency for existing orders based on their country_code
    say_with_time "Backfilling fulfillment_currency for existing orders" do
      orders_updated = 0
      
      Order.where(fulfillment_currency: nil).find_each do |order|
        next unless order.country_code.present?
        
        # Get currency from country config
        country_config = CountryConfig.for_country(order.country_code)
        fulfillment_currency = country_config&.dig("currency")
        
        if fulfillment_currency.present?
          # Use update_column to skip callbacks and validations for performance
          order.update_column(:fulfillment_currency, fulfillment_currency)
          orders_updated += 1
        end
      end
      
      say "Updated #{orders_updated} orders with fulfillment_currency", true
      orders_updated
    end
  end
  
  def down
    # No-op: We don't want to remove fulfillment_currency data on rollback
    say "Cannot rollback data migration - fulfillment_currency data will remain"
  end
end
