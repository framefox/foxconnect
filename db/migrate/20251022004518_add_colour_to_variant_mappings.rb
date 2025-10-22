class AddColourToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :colour, :string
  end
end
