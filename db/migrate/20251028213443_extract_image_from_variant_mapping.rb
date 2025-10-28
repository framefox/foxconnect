class ExtractImageFromVariantMapping < ActiveRecord::Migration[8.0]
  def up
    # Create images table
    create_table :images do |t|
      t.integer :external_image_id, null: false
      t.string :image_key, null: false
      t.string :cloudinary_id
      t.integer :image_width
      t.integer :image_height
      t.string :image_filename
      t.integer :cx, null: false
      t.integer :cy, null: false
      t.integer :cw, null: false
      t.integer :ch, null: false

      t.timestamps
    end

    add_index :images, :external_image_id

    # Rename the current image_id column to preserve external image IDs during migration
    rename_column :variant_mappings, :image_id, :external_image_id_temp

    # Add new image_id column as foreign key to images table (nullable)
    add_reference :variant_mappings, :image, foreign_key: true, null: true

    # Migrate existing data - create Image records and link them
    # We'll do this in batches to avoid memory issues
    say_with_time "Migrating variant_mapping image data to images table" do
      VariantMapping.find_each do |vm|
        # Only create image if the variant mapping has image data
        if vm.external_image_id_temp.present? && vm.image_key.present? &&
           vm.cx.present? && vm.cy.present? && vm.cw.present? && vm.ch.present?

          image = Image.create!(
            external_image_id: vm.external_image_id_temp,
            image_key: vm.image_key,
            cloudinary_id: vm.cloudinary_id,
            image_width: vm.image_width,
            image_height: vm.image_height,
            image_filename: vm.image_filename,
            cx: vm.cx,
            cy: vm.cy,
            cw: vm.cw,
            ch: vm.ch,
            created_at: vm.created_at,
            updated_at: vm.updated_at
          )

          vm.update_column(:image_id, image.id)
        end
      end
    end

    # Remove old columns from variant_mappings
    remove_column :variant_mappings, :external_image_id_temp, :integer
    remove_column :variant_mappings, :image_key, :string
    remove_column :variant_mappings, :cloudinary_id, :string
    remove_column :variant_mappings, :image_width, :integer
    remove_column :variant_mappings, :image_height, :integer
    remove_column :variant_mappings, :image_filename, :string
    remove_column :variant_mappings, :cx, :integer
    remove_column :variant_mappings, :cy, :integer
    remove_column :variant_mappings, :cw, :integer
    remove_column :variant_mappings, :ch, :integer
  end

  def down
    # Add back the old columns to variant_mappings
    add_column :variant_mappings, :image_key, :string
    add_column :variant_mappings, :cloudinary_id, :string
    add_column :variant_mappings, :image_width, :integer
    add_column :variant_mappings, :image_height, :integer
    add_column :variant_mappings, :image_filename, :string
    add_column :variant_mappings, :cx, :integer
    add_column :variant_mappings, :cy, :integer
    add_column :variant_mappings, :cw, :integer
    add_column :variant_mappings, :ch, :integer
    add_column :variant_mappings, :external_image_id_temp, :integer

    # Migrate data back from images table
    say_with_time "Migrating image data back to variant_mappings" do
      VariantMapping.find_each do |vm|
        if vm.image.present?
          vm.update_columns(
            external_image_id_temp: vm.image.external_image_id,
            image_key: vm.image.image_key,
            cloudinary_id: vm.image.cloudinary_id,
            image_width: vm.image.image_width,
            image_height: vm.image.image_height,
            image_filename: vm.image.image_filename,
            cx: vm.image.cx,
            cy: vm.image.cy,
            cw: vm.image.cw,
            ch: vm.image.ch
          )
        end
      end
    end

    # Rename back to image_id
    rename_column :variant_mappings, :external_image_id_temp, :image_id

    # Remove the foreign key and image_id reference
    remove_reference :variant_mappings, :image, foreign_key: true

    # Drop images table
    drop_table :images
  end
end
