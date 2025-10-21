class OrderMailer < ApplicationMailer
  # Sends an email to the customer when an order is imported in draft state.
  # Use with: OrderMailer.with(order_id: id).draft_imported
  def draft_imported
    order_id = params[:order_id]
    @order = Order.includes(:shipping_address, order_items: [ :product_variant, :variant_mapping ]).find(order_id)

    return if @order.customer_email.blank?

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    # Use country-specific sender email
    from_email = format_from_email(order_from_email(@order))

    mail(
      to: @order.customer_email,
      from: from_email,
      subject: "Your order #{order_subject_name(@order)} has been imported"
    )
  end

  # Sends an email to the customer when items from their order are fulfilled.
  # Use with: OrderMailer.with(order_id: id, fulfillment_id: id).fulfillment_notification
  def fulfillment_notification
    order_id = params[:order_id]
    fulfillment_id = params[:fulfillment_id]

    @order = Order.includes(:shipping_address, order_items: [ :product_variant, :variant_mapping ]).find(order_id)
    @fulfillment = Fulfillment.includes(fulfillment_line_items: { order_item: [ :product_variant, :variant_mapping ] }).find(fulfillment_id)

    return if @order.customer_email.blank?

    # Attach logo inline for email
    attachments.inline["logo-connect-sm.png"] = File.read(Rails.root.join("app/assets/images/logo-connect-sm.png"))

    # Use country-specific sender email
    from_email = format_from_email(order_from_email(@order))

    mail(
      to: @order.customer_email,
      from: from_email,
      subject: "Items fulfilled for order #{order_subject_name(@order)}"
    )
  end

  private

  def order_subject_name(order)
    order.display_name
  end

  def order_from_email(order)
    CountryConfig.for_country(order.country_code)["email_from"]
  end
end
