class AddDimensionsToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :long, :integer
    add_column :variant_mappings, :short, :integer
    add_column :variant_mappings, :unit, :string
  end
end
