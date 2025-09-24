class RemoveDescriptionFieldsFromProducts < ActiveRecord::Migration[8.0]
  def change
    remove_column :products, :description, :text
    remove_column :products, :description_html, :text
  end
end
