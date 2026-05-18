# Copies template variant_mappings from a source product onto a target product
# by matching variants on case-insensitive, whitespace-trimmed title.
#
# Behaviour:
# - Same-store only is enforced by the caller (controller).
# - For each target variant whose normalised title matches a source variant:
#   1. The target variant's bundle slot_count is set to match the source's.
#   2. All existing template variant_mappings on the target variant are destroyed
#      (and any orphaned Image records are cleaned up).
#   3. Each source template mapping (scope :templates) is copied across, with
#      image_id explicitly nil. country_code and slot_position are preserved.
# - Non-matching target variants are left untouched.
class CopyProductVariantMappingsService
  Result = Struct.new(
    :variants_matched,
    :variants_skipped,
    :mappings_copied,
    :mappings_removed,
    keyword_init: true
  )

  COPYABLE_ATTRS = %i[
    frame_sku_id
    frame_sku_code
    frame_sku_title
    frame_sku_description
    frame_sku_cost_cents
    frame_sku_long
    frame_sku_short
    frame_sku_unit
    width
    height
    unit
    colour
    country_code
    slot_position
    preview_url
    paper_type_id
  ].freeze

  def initialize(source_product:, target_product:)
    @source_product = source_product
    @target_product = target_product
  end

  def call
    target_index = build_target_index

    variants_matched = 0
    mappings_copied = 0
    mappings_removed = 0

    ActiveRecord::Base.transaction do
      @source_product.product_variants.present_in_source.includes(:bundle).each do |source_variant|
        normalised = normalise_title(source_variant.title)
        target_variant = target_index[normalised]
        next unless target_variant

        variants_matched += 1

        target_bundle = ensure_bundle(target_variant)
        source_bundle = source_variant.bundle

        if source_bundle.present? && source_bundle.slot_count != target_bundle.slot_count
          target_bundle.update!(slot_count: source_bundle.slot_count)
        end

        mappings_removed += wipe_existing_mappings(target_variant)

        source_templates = source_variant.variant_mappings.templates.to_a
        source_templates.each do |source_mapping|
          attrs = source_mapping.attributes.symbolize_keys.slice(*COPYABLE_ATTRS)
          VariantMapping.create!(
            attrs.merge(
              bundle_id: target_bundle.id,
              product_variant_id: target_variant.id,
              order_item_id: nil,
              image_id: nil,
              is_default: source_mapping.is_default
            )
          )
          mappings_copied += 1
        end
      end
    end

    Result.new(
      variants_matched: variants_matched,
      variants_skipped: @target_product.product_variants.present_in_source.count - variants_matched,
      mappings_copied: mappings_copied,
      mappings_removed: mappings_removed
    )
  end

  private

  def build_target_index
    @target_product.product_variants.present_in_source.each_with_object({}) do |pv, hash|
      key = normalise_title(pv.title)
      next if key.blank?
      hash[key] ||= pv
    end
  end

  def normalise_title(title)
    title.to_s.strip.downcase
  end

  def ensure_bundle(variant)
    variant.bundle || variant.create_bundle!(slot_count: 1)
  end

  # Destroys template variant_mappings on this variant and cleans up any
  # orphaned Image records. Order-item-scoped mappings are left untouched.
  def wipe_existing_mappings(variant)
    template_mappings = variant.variant_mappings.where(order_item_id: nil).to_a
    image_ids = template_mappings.map(&:image_id).compact.uniq
    template_mappings.each(&:destroy!)

    image_ids.each do |image_id|
      next if VariantMapping.where(image_id: image_id).exists?
      Image.where(id: image_id).destroy_all
    end

    template_mappings.size
  end
end
