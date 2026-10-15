class RecoverVariantMappingPreviewJob < ApplicationJob
  queue_as :default
  retry_on FrameSkuPreviewService::Unavailable, wait: :polynomially_longer, attempts: 3

  def perform(mapping_id)
    mapping = VariantMapping.find_by(id: mapping_id)
    return unless mapping&.image.present? && mapping.preview_url.blank?

    sku_id = mapping.frame_sku_id
    country_code = mapping.country_code
    preview = FrameSkuPreviewService.call(frame_sku_id: sku_id, country_code: country_code)
    mapping.with_lock do
      # A user may have replaced the product or removed the artwork during lookup.
      if mapping.image.present? && mapping.preview_url.blank? &&
          mapping.frame_sku_id == sku_id && mapping.country_code == country_code
        mapping.update!(preview_url: preview)
      end
    end
  end
end
