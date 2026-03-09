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

  # Sends an email to admin when an order from a non-matching country is attempted to be imported
  # Use with: AdminMailer.country_mismatch_order(store:, user:, order_data:, shipping_country:).deliver_later
  def country_mismatch_order(store:, user:, order_data:, shipping_country:)
    @store = store
    @user = user
    @order_data = order_data
    @shipping_country = shipping_country
    @user_country = user.country
    @order_name = order_data["name"]
    @order_id = extract_id_from_gid(order_data["id"])
    @raw_json = JSON.pretty_generate(order_data)

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    mail(
      from: "notifications@framefox.co.nz",
      subject: "⚠️ Order Import Blocked - Country Mismatch: #{@order_name}"
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

  private

  def extract_id_from_gid(gid)
    gid.to_s.split("/").last
  end
end

