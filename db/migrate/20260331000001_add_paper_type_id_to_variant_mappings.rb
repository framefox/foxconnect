class AddPaperTypeIdToVariantMappings < ActiveRecord::Migration[8.0]
  def change
    add_column :variant_mappings, :paper_type_id, :integer
  end
end
