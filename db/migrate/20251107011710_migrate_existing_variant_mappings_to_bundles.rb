class MigrateExistingVariantMappingsToBundles < ActiveRecord::Migration[8.0]
  def up
    # First, clear any existing bundle data from previous partial migrations
    VariantMapping.where.not(bundle_id: nil).update_all(
      bundle_id: nil,
      slot_position: nil
    )
    
    # Create a bundle for every existing ProductVariant
    ProductVariant.find_each do |variant|
      # Skip if bundle already exists
      bundle = variant.bundle
      unless bundle
        bundle = Bundle.create!(
          product_variant: variant,
          slot_count: 1
        )
      end
      
      # For initial migration, only migrate DEFAULT variant mappings to bundles
      # Non-default mappings will continue using product_variant_id for backward compatibility
      # We'll migrate one default mapping per country to avoid unique constraint issues
      default_mappings = VariantMapping.where(
        product_variant_id: variant.id,
        order_item_id: nil,
        bundle_id: nil,
        is_default: true
      )
      
      # Take only the first default mapping (typically there should be one per country)
      # For variants with multiple countries, we'll need to handle them as multi-slot bundles later
      default_mappings.limit(1).each do |mapping|
        mapping.update_columns(
          bundle_id: bundle.id,
          slot_position: 1
        )
      end
    end
  end
  
  def down
    # Revert: Remove bundle associations from variant mappings
    VariantMapping.where.not(bundle_id: nil).update_all(
      bundle_id: nil,
      slot_position: nil
    )
    
    # Delete all bundles
    Bundle.destroy_all
  end
end
