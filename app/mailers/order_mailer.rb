class OrderMailer < ApplicationMailer
  # Sends an email to the customer when an order is imported in draft state.
  # Use with: OrderMailer.with(order_id: id).draft_imported
  def draft_imported
    order_id = params[:order_id]
    @order = Order.includes(:shipping_address, order_items: [ :product_variant, :variant_mapping ]).find(order_id)

    return if @order.customer_email.blank?

    # Use country-specific sender email
    from_email = order_from_email(@order)

    mail(
      to: @order.customer_email,
      from: from_email,
      subject: "Your order #{order_subject_name(@order)} has been imported"
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
