namespace :variant_mappings do
  desc "Queue preview recovery for existing mappings with artwork but no renderer URL"
  task repair_missing_previews: :environment do
    count = 0
    VariantMapping.joins(:image).where(preview_url: [nil, ""]).find_each do |mapping|
      RecoverVariantMappingPreviewJob.perform_later(mapping.id)
      count += 1
    end
    puts "Queued preview recovery for #{count} mappings. Artwork and crops are preserved."
  end
end
