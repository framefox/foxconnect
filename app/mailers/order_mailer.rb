class OrderMailer < ApplicationMailer
  # Sends an email to the customer when an order is imported in draft state.
  # Use with: OrderMailer.with(order_id: id).draft_imported
  def draft_imported
    order_id = params[:order_id]
    # Ruby 2.6 requires the hash to be the last arg when braces are omitted
    @order = Order.includes(:shipping_address, order_items: [ :product_variant, :variant_mapping ]).find(order_id)

    return if @order.customer_email.blank?

    mail(
      to: @order.customer_email,
      subject: "Your order #{order_subject_name(@order)} has been imported"
    )
  end

  private

  def order_subject_name(order)
    order.display_name
  end
end
