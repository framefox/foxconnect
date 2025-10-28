class AddMockupBgColourToStores < ActiveRecord::Migration[8.0]
  def change
    add_column :stores, :mockup_bg_colour, :string, default: 'f4f4f4'
  end
end
