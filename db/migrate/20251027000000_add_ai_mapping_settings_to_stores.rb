class AddAiMappingSettingsToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :ai_mapping_enabled, :boolean, default: false
    add_column :stores, :ai_mapping_prompt, :text
  end
end

