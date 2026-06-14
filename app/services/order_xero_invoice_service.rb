class OrderXeroInvoiceService
  class InvoiceError < StandardError; end

  DEFAULT_SALES_ACCOUNT_CODES = {
    "NZ" => "SH-20000",
    "AU" => "SH-20000-A"
  }.freeze
  DEFAULT_SHIPPING_ACCOUNT_CODES = {
    "NZ" => "SH-20002",
    "AU" => "SH-20002-A"
  }.freeze

  attr_reader :order, :xero_service

  def initialize(order:, xero_service: nil)
    @order = order
    @xero_service = xero_service
  end

  def call(raise_on_failure: false)
    return success(skipped: true) if order.xero_invoiced?

    result = service.create_invoice(
      contact_id: xero_contact_id,
      line_items: build_line_items,
      date: invoice_date,
      due_date: due_date,
      reference: invoice_reference,
      status: "AUTHORISED",
      currency: currency,
      idempotency_key: idempotency_key
    )

    order.update!(
      xero_invoice_id: result[:invoice_id],
      xero_invoice_number: result[:invoice_number],
      xero_invoice_url: result[:invoice_url],
      xero_online_invoice_url: result[:online_invoice_url],
      xero_invoice_due_date: due_date,
      xero_invoiced_at: Time.current,
      xero_invoice_error: nil
    )

    success(result: result)
  rescue => e
    order.update!(xero_invoice_error: e.message) if order.persisted?
    Rails.logger.error "OrderXeroInvoiceService failed for Order ##{order.id}: #{e.message}"
    raise e if raise_on_failure

    { success: false, error: e.message }
  end

  def build_line_items
    items = product_line_items

    if order.production_shipping_cents.positive?
      items << {
        description: "#{order.invoice_order_reference} - Shipping",
        quantity: 1,
        unit_amount: money_amount(order.production_shipping_cents),
        account_code: shipping_account_code
      }
    end

    raise InvoiceError, "Order has no production amounts to invoice" if items.empty?

    items
  end

  def due_date
    StatementDeliverySchedule.due_date_for(order.in_production_at || Time.current)
  end

  def invoice_date
    (order.in_production_at || Time.current).in_time_zone(StatementDeliverySchedule::TIME_ZONE).to_date
  end

  def idempotency_key
    "foxconnect-order-xero-invoice-#{Rails.env}-#{order.id}"
  end

  private

  def success(result: nil, skipped: false)
    { success: true, skipped: skipped, result: result }
  end

  def service
    @service ||= xero_service || XeroService.new(order.country_code)
  end

  def company
    @company ||= order.xero_company
  end

  def xero_contact_id
    raise InvoiceError, "Order has no Xero-enabled company" unless company&.xero_contact_id.present?

    company.xero_contact_id
  end

  def invoice_reference
    sales_order = order.shopify_remote_order_name.presence || order.display_name
    customer_reference = order.invoice_order_reference

    [ "Framefox Connect | Sales Order", sales_order, customer_reference ].compact_blank.join(" ")
  end

  def currency
    order.fulfillment_currency || order.currency
  end

  def country_config
    @country_config ||= CountryConfig.for_country(order.country_code)
  end

  def sales_account_code
    country_config&.dig("xero_sales_account_code") ||
      country_config&.dig("xero_account_code") ||
      DEFAULT_SALES_ACCOUNT_CODES[order.country_code]
  end

  def shipping_account_code
    country_config&.dig("xero_shipping_account_code") ||
      DEFAULT_SHIPPING_ACCOUNT_CODES[order.country_code] ||
      sales_account_code
  end

  def money_amount(cents)
    cents / 100.0
  end

  def product_line_items
    return [] unless order.production_subtotal_cents.positive?

    product_items = order.fulfillable_items
    return [ fallback_product_line_item ] if product_items.empty?

    allocated_product_amounts(product_items).filter_map do |item, amount_cents|
      next if amount_cents <= 0

      {
        description: product_description(item),
        quantity: 1,
        unit_amount: money_amount(amount_cents),
        account_code: sales_account_code
      }
    end
  end

  def fallback_product_line_item
    {
      description: "#{order.invoice_order_reference} - Products",
      quantity: 1,
      unit_amount: money_amount(order.production_subtotal_cents),
      account_code: sales_account_code
    }
  end

  def allocated_product_amounts(product_items)
    weights = product_items.map { |item| item.production_cost_cents.to_i * item.quantity.to_i }
    weights = product_items.map { |item| item.quantity.to_i } unless weights.sum.positive?

    product_items.zip(allocate_cents(order.production_subtotal_cents, weights))
  end

  def allocate_cents(total_cents, weights)
    return [] if weights.empty?

    weight_sum = weights.sum
    if weight_sum.zero?
      base = total_cents / weights.size
      remainder = total_cents % weights.size
      return weights.each_index.map { |index| base + (index < remainder ? 1 : 0) }
    end

    raw_allocations = weights.map { |weight| Rational(total_cents * weight, weight_sum) }
    allocations = raw_allocations.map(&:floor)
    remainder = total_cents - allocations.sum

    remainder_indices = raw_allocations
      .each_with_index
      .sort_by { |allocation, index| [ -(allocation - allocation.floor), index ] }
      .map(&:last)

    remainder_indices.first(remainder).each { |index| allocations[index] += 1 }
    allocations
  end

  def product_description(item)
    description = item.display_name.presence || item.sku.presence || "Product"
    item.quantity.to_i > 1 ? "#{description} (x#{item.quantity})" : description
  end
end
