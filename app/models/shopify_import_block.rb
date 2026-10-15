# Retains notification deduplication even after webhook logs are cleaned up.
class ShopifyImportBlock < ApplicationRecord
  belongs_to :store

  def self.notify_once!(store:, order_data:, shipping_country:)
    block = create_or_find_by!(store: store, external_order_id: order_data.fetch("id").to_s.split("/").last)
    block.with_lock do
      return if block.notified_at?

      email = AdminMailer.country_mismatch_order(store: store, user: store.user,
        order_data: order_data, shipping_country: shipping_country)
      Rails.env.development? ? email.deliver_now : email.deliver_later
      block.update!(notified_at: Time.current)
    end
  end
end
