class AddStoreToProducts < ActiveRecord::Migration[8.0]
  def change
    # First, remove any existing test data (variants first due to foreign key)
    ProductVariant.delete_all
    Product.delete_all
    
    # Add the store reference
    add_reference :products, :store, null: false, foreign_key: true
    
    # Update the unique index to include store_id since external_id is unique per store, not per platform
    remove_index :products, [:platform, :external_id]
    add_index :products, [:store_id, :external_id], unique: true
  end
end
