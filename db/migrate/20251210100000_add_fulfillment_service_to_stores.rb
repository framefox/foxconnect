class AddFulfillmentServiceToStores < ActiveRecord::Migration[8.0]
  def change
    # Fulfillment service fields for Shopify stores
    # When a Shopify store connects, we register as a fulfillment service
    # which creates a dedicated location for our app to fulfill orders from
    add_column :stores, :shopify_fulfillment_service_id, :string
    add_column :stores, :shopify_fulfillment_location_id, :string

    # Index for quick lookups when processing fulfillment requests
    add_index :stores, :shopify_fulfillment_service_id, unique: true,
              where: "shopify_fulfillment_service_id IS NOT NULL"
  end
end

