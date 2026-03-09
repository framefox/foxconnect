class AddCountryCodeAndXeroContactIdToCompanies < ActiveRecord::Migration[8.0]
  def change
    add_column :companies, :country_code, :string, limit: 2
    add_column :companies, :xero_contact_id, :string

    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE companies
          SET country_code = (
            SELECT sc.country_code
            FROM shopify_customers sc
            WHERE sc.company_id = companies.id
            LIMIT 1
          )
        SQL
      end
    end
  end
end
