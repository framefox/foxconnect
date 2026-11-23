class AddEnabledFulfilmentCountriesToStores < ActiveRecord::Migration[8.0]
  def up
    add_column :stores, :enabled_fulfilment_countries, :string, array: true

    # Preserve the old Shopify import policy, including blank home countries
    # (which previously allowed both supported destinations).
    execute <<~SQL
      UPDATE stores
      SET enabled_fulfilment_countries = CASE
        WHEN users.country IN ('NZ', 'AU') THEN ARRAY[users.country]::varchar[]
        WHEN users.country IS NULL OR BTRIM(users.country) = '' THEN ARRAY['NZ', 'AU']::varchar[]
        ELSE ARRAY[]::varchar[]
      END
      FROM users
      WHERE users.id = stores.created_by_user_id
    SQL
    execute "UPDATE stores SET enabled_fulfilment_countries = ARRAY[]::varchar[] WHERE enabled_fulfilment_countries IS NULL"
    change_column_null :stores, :enabled_fulfilment_countries, false
  end

  def down
    remove_column :stores, :enabled_fulfilment_countries
  end
end
