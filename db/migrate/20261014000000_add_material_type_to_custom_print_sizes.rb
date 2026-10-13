class AddMaterialTypeToCustomPrintSizes < ActiveRecord::Migration[8.0]
  def change
    # Leave existing sizes unclassified: their pricing size does not tell us
    # whether the customer originally intended paper or canvas.
    add_column :custom_print_sizes, :material_type, :string
    add_check_constraint :custom_print_sizes,
      "material_type IN ('paper', 'canvas')",
      name: "custom_print_sizes_material_type"
  end
end
