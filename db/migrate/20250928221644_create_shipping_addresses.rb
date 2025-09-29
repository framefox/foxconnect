class CreateShippingAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :shipping_addresses do |t|
      t.references :order, null: false, foreign_key: true

      # Standard fields that map well across Shopify, Wix, Squarespace
      t.string :first_name
      t.string :last_name
      t.string :company
      t.string :name           # full name if provided by platform
      t.string :phone

      t.string :address1
      t.string :address2
      t.string :city
      t.string :province       # state/region name
      t.string :province_code  # state/region code (e.g., CA, NSW)
      t.string :postal_code
      t.string :country
      t.string :country_code   # ISO 2-letter code

      t.float  :latitude
      t.float  :longitude

      t.timestamps
    end

    add_index :shipping_addresses, :order_id, unique: true unless index_exists?(:shipping_addresses, :order_id)
    add_check_constraint :shipping_addresses, "char_length(country_code) IN (0, 2)", name: "ship_addr_country_code_len"
    add_check_constraint :shipping_addresses, "char_length(province_code) IN (0, 2, 3)", name: "ship_addr_province_code_len"
  end
end
