class CreateCompanies < ActiveRecord::Migration[8.0]
  def change
    create_table :companies do |t|
      t.string :company_name, null: false
      t.string :shopify_company_id, null: false
      t.string :shopify_company_location_id, null: false
      t.string :shopify_company_contact_id, null: false

      t.timestamps
    end

    add_index :companies, :shopify_company_id, unique: true
  end
end
