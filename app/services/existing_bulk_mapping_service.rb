class ExistingBulkMappingService
  class Unavailable < StandardError; end

  SKU_FIELDS = %w[id code title description cost_cents long short unit].freeze
  PRODUCT_FIELDS = %w[frame_sku_id frame_sku_code frame_sku_long frame_sku_short frame_sku_unit colour paper_type_id border_width_mm].freeze

  def self.call(store:, variant_title:, country_code:)
    variants = store.product_variants.present_in_source.where(title: variant_title)
    mappings = VariantMapping.where(product_variant_id: variants.select(:id),
      is_default: true, country_code: country_code, order_item_id: nil).includes(:bundle).order(:id).to_a

    if mappings.empty?
      raise Unavailable, "No existing mapping is available. Use Bulk Assign to choose a product."
    end

    if mappings.map { |mapping| mapping.attributes.slice(*PRODUCT_FIELDS) }.uniq.size > 1 ||
        mappings.any? { |mapping| mapping.bundle && mapping.bundle.slot_count > 1 }
      raise Unavailable, "This row has different mappings or a bundle. Use Bulk Assign to choose a product for the remaining variants."
    end

    source = mappings.first
    # Artwork previews belong to the source variant, not to the Framefox product.
    SKU_FIELDS.to_h { |field| [ field, source.public_send("frame_sku_#{field}") ] }.merge(
      "colour" => source.colour,
      "paper_type_id" => source.paper_type_id,
      "border_width_mm" => source.border_width_mm
    )
  end
end
