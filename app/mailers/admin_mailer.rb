class AdminMailer < ApplicationMailer
  default to: "george@framefox.co.nz"

  # Sends an email to admin when a new store is created
  # Use with: AdminMailer.new_store_created(store:).deliver_later
  def new_store_created(store:)
    @store = store
    @user = store.user
    @platform = store.platform_display_name
    @store_identifier = store.display_identifier

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    mail(
      from: "notifications@framefox.co.nz",
      subject: "🎉 New Store Created - #{@store.name}"
    )
  end

  # Sends a summary of payment-pending orders across remote Shopify stores
  # Use with: AdminMailer.pending_payment_orders(stores_data: [...]).deliver_now
  def pending_payment_orders(stores_data:)
    @stores_data = stores_data
    @total_orders = stores_data.sum { |s| s[:order_count] }

    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    mail(
      from: "notifications@framefox.co.nz",
      subject: "Payment Pending Orders Report - #{@total_orders} order(s)"
    )
  end

end

