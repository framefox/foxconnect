namespace :orders do
  desc "Send daily reminder emails to store owners about orders in draft status"
  task draft_reminder: :environment do
    organizations_with_drafts = Organization
      .joins(stores: :orders)
      .where(orders: { aasm_state: "draft" })
      .distinct

    sent_count = 0

    organizations_with_drafts.find_each do |org|
      draft_orders = Order
        .joins(:store)
        .includes(:store, :shipping_address, :order_items)
        .where(stores: { organization_id: org.id })
        .where(aasm_state: "draft")
        .order(created_at: :desc)

      next if draft_orders.empty?

      StoreMailer.with(organization: org, orders: draft_orders).draft_orders_reminder.deliver_now
      sent_count += 1
      puts "Sent draft orders reminder to #{org.name} (#{draft_orders.size} orders)"
    end

    if sent_count > 0
      puts "\nSent #{sent_count} draft order reminder email(s)."
    else
      puts "No organizations with draft orders found."
    end
  end
end
