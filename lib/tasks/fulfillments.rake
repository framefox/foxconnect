namespace :fulfillments do
  desc "Backfill source column on existing fulfillments and re-sync production fulfillments to customer stores"
  task backfill_source: :environment do
    puts "Backfilling fulfillment sources..."

    production_count = 0
    manual_count = 0

    Fulfillment.find_each do |fulfillment|
      source = fulfillment.shopify_fulfillment_id.present? ? "production_webhook" : "manual"
      fulfillment.update_column(:source, source)

      if source == "production_webhook"
        production_count += 1
      else
        manual_count += 1
      end
    end

    puts "Done. #{production_count} production_webhook, #{manual_count} manual."
  end
end
