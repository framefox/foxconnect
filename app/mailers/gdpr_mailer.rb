class GdprMailer < ApplicationMailer
  default to: -> { ENV.fetch("ADMIN_EMAIL", "admin@framefox.co.nz") }

  def customer_data_request(webhook_data)
    @webhook_data = webhook_data
    @shop_domain = webhook_data["shop_domain"]
    @customer_email = webhook_data.dig("customer", "email")
    @customer_id = webhook_data.dig("customer", "id")
    @orders_requested = webhook_data["orders_requested"]
    @orders_count = @orders_requested&.count || 0
    @timestamp = Time.current

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    mail(
      subject: "GDPR: Customer Data Request - #{@shop_domain}",
      from: format_from_email("frames@framefox.co.nz")
    )
  end

  def customer_redact(webhook_data)
    @webhook_data = webhook_data
    @shop_domain = webhook_data["shop_domain"]
    @customer_email = webhook_data.dig("customer", "email")
    @customer_id = webhook_data.dig("customer", "id")
    @customer_phone = webhook_data.dig("customer", "phone")
    @orders_to_redact = webhook_data["orders_to_redact"]
    @orders_count = @orders_to_redact&.count || 0
    @timestamp = Time.current

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    mail(
      subject: "GDPR: Customer Data Redaction Request - #{@shop_domain}",
      from: format_from_email("frames@framefox.co.nz")
    )
  end

  def shop_redact(webhook_data)
    @webhook_data = webhook_data
    @shop_domain = webhook_data["shop_domain"]
    @shop_id = webhook_data["shop_id"]
    @timestamp = Time.current

    # Try to find the store and get additional info
    @store = Store.find_by(shopify_domain: @shop_domain)
    @store_name = @store&.name
    @store_user_email = @store&.user&.email
    @orders_count = @store&.orders&.count || 0
    @products_count = @store&.products&.count || 0

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    mail(
      subject: "GDPR: Shop Deletion Request - #{@shop_domain}",
      from: format_from_email("frames@framefox.co.nz")
    )
  end
end
