class OrderMailer < ApplicationMailer
  # Sends an email to all organization users when an order is imported in draft state.
  # Use with: OrderMailer.with(order_id: id).draft_imported
  def draft_imported
    order_id = params[:order_id]
    @order = Order.includes(:store, :user, :shipping_address, order_items: [ :product_variant, :variant_mapping, :variant_mappings ]).find(order_id)

    recipients = @order.notification_emails
    return if recipients.empty?

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    # Use country-specific sender email
    from_email = format_from_email(order_from_email(@order))
    subject = "Your order #{order_subject_name(@order)} has been imported [Action Required]"

    # Log activity
    @order.log_activity(
      activity_type: "email_draft_imported",
      title: "Draft imported email sent",
      description: "Email sent to #{recipients.join(', ')}",
      metadata: {
        email_type: "draft_imported",
        recipients: recipients,
        subject: subject
      }
    )

    mail(
      to: recipients,
      cc: "george@framefox.co.nz",
      from: from_email,
      subject: subject
    )
  end

  # Sends an email to all organization users when items from their order are fulfilled.
  # Use with: OrderMailer.with(order_id: id, fulfillment_id: id).fulfillment_notification
  def fulfillment_notification
    order_id = params[:order_id]
    fulfillment_id = params[:fulfillment_id]

    @order = Order.includes(:store, :user, :shipping_address, order_items: [ :product_variant, :variant_mapping, :variant_mappings ]).find(order_id)
    @fulfillment = Fulfillment.includes(fulfillment_line_items: { order_item: [ :product_variant, :variant_mapping, :variant_mappings ] }).find(fulfillment_id)

    recipients = @order.notification_emails
    return if recipients.empty?

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    # Use country-specific sender email
    from_email = format_from_email(order_from_email(@order))

    # Log activity
    @order.log_activity(
      activity_type: "email_fulfillment_notification",
      title: "Fulfillment notification email sent",
      description: "Email sent to #{recipients.join(', ')} for fulfillment ##{@fulfillment.id}",
      metadata: {
        email_type: "fulfillment_notification",
        fulfillment_id: @fulfillment.id,
        recipients: recipients,
        subject: "Items fulfilled for order #{order_subject_name(@order)}",
        tracking_company: @fulfillment.tracking_company,
        tracking_number: @fulfillment.tracking_number
      }
    )

    mail(
      to: recipients,
      from: from_email,
      subject: "Items fulfilled for order #{order_subject_name(@order)}"
    )
  end

  private

  def order_subject_name(order)
    order.display_name
  end

  def order_from_email(order)
    config = CountryConfig.for_country(order.country_code)
    # Fallback to NZ config if order country config doesn't exist
    config ||= CountryConfig.for_country("NZ")
    config["email_from"]
  end
end
