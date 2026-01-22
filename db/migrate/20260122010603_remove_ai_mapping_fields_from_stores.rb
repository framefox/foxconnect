class RemoveAiMappingFieldsFromStores < ActiveRecord::Migration[8.0]
  def change
    remove_column :stores, :ai_mapping_enabled, :boolean, default: false
    remove_column :stores, :ai_mapping_prompt, :text
  end
end
