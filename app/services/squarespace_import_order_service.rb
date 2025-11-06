class SquarespaceImportOrderService
  attr_reader :store, :order_id

  def initialize(store:, order_id:)
    @store = store
    @order_id = order_id
  end

  def call
    return nil unless store.squarespace?

    # Block imports from inactive stores
    unless store.active?
      Rails.logger.warn "Attempted to import order from inactive store: #{store.name}"
      return nil
    end

    Rails.logger.info "Importing order #{order_id} from Squarespace store: #{store.name}"

    # Create API service
    api_service = SquarespaceApiService.new(
      access_token: store.squarespace_token,
      store: store
    )

    # Fetch order from Squarespace
    begin
      order_data = api_service.get_order(order_id)
      import_order(order_data)
    rescue SquarespaceApiService::SquarespaceApiError => e
      Rails.logger.error "Squarespace API error: #{e.message}"
      raise StandardError, "Failed to fetch order from Squarespace: #{e.message}"
    end
  end

  def resync_order(existing_order)
    return nil unless store.squarespace?

    Rails.logger.info "Resyncing order #{existing_order.external_id} from Squarespace"

    # Create API service
    api_service = SquarespaceApiService.new(
      access_token: store.squarespace_token,
      store: store
    )

    # Fetch fresh order data
    begin
      order_data = api_service.get_order(existing_order.external_id)
      update_order(existing_order, order_data)
    rescue SquarespaceApiService::SquarespaceApiError => e
      Rails.logger.error "Squarespace API error during resync: #{e.message}"
      raise StandardError, "Failed to resync order from Squarespace: #{e.message}"
    end
  end

  private

  def import_order(order_data)
    created_new_order = false
    order = ActiveRecord::Base.transaction do
      # Check if order already exists
      external_id = order_data["id"]
      existing_order = Order.find_by(store: store, external_id: external_id)

      if existing_order
        Rails.logger.info "Order #{external_id} already exists, updating..."
        order = existing_order
      else
        Rails.logger.info "Creating new order #{external_id}..."
        order = Order.new(store: store, external_id: external_id)
        created_new_order = true
      end

      # Validate currency before proceeding
      currency_code = extract_currency(order_data)
      if currency_code.blank?
        raise StandardError, "Order currency code is missing from Squarespace data"
      end

      # Validate it's a valid currency
      begin
        Money::Currency.new(currency_code)
      rescue Money::Currency::UnknownCurrency
        raise StandardError, "Invalid currency code from Squarespace: #{currency_code}"
      end

      # Extract country code from shipping address
      shipping_country_code = order_data.dig("shippingAddress", "countryCode")

      # Map order fields
      order.assign_attributes(
        external_number: order_data["orderNumber"],
        name: "##{order_data['orderNumber']}",
        customer_email: order_data["customerEmail"],
        customer_phone: order_data.dig("shippingAddress", "phone") || order_data.dig("billingAddress", "phone"),
        currency: currency_code,
        country_code: shipping_country_code,
        subtotal_price_cents: extract_money_cents(order_data["subtotal"]),
        total_discounts_cents: extract_money_cents(order_data["discountTotal"]),
        total_shipping_cents: extract_money_cents(order_data["shippingTotal"]),
        total_tax_cents: extract_money_cents(order_data["taxTotal"]),
        total_price_cents: extract_money_cents(order_data["grandTotal"]),
        processed_at: parse_datetime(order_data["createdOn"]),
        cancelled_at: map_fulfillment_status(order_data["fulfillmentStatus"]) == "CANCELED" ? parse_datetime(order_data["modifiedOn"]) : nil,
        cancel_reason: map_fulfillment_status(order_data["fulfillmentStatus"]) == "CANCELED" ? "Cancelled in Squarespace" : nil,
        tags: build_tags(order_data),
        note: build_notes(order_data),
        raw_payload: order_data
      )

      order.save!

      # Import shipping address
      if order_data["shippingAddress"]
        import_shipping_address(order, order_data["shippingAddress"])
      else
        # Remove shipping address if it no longer exists
        order.shipping_address&.destroy
      end

      # Import order items
      if order_data["lineItems"]
        import_order_items(order, order_data["lineItems"])
      end

      # Log activity
      if created_new_order
        order.order_activities.create!(
          activity_type: "order_imported",
          description: "Order imported from Squarespace",
          metadata: { source: "squarespace", order_number: order_data["orderNumber"] }
        )
      end

      Rails.logger.info "Successfully imported order #{order.display_name} (ID: #{order.id})"
      order
    end
  end

  def update_order(order, order_data)
    ActiveRecord::Base.transaction do
      # Extract country code from shipping address
      shipping_country_code = order_data.dig("shippingAddress", "countryCode")

      # Update order fields
      order.assign_attributes(
        external_number: order_data["orderNumber"],
        name: "##{order_data['orderNumber']}",
        customer_email: order_data["customerEmail"],
        customer_phone: order_data.dig("shippingAddress", "phone") || order_data.dig("billingAddress", "phone"),
        currency: extract_currency(order_data),
        country_code: shipping_country_code,
        subtotal_price_cents: extract_money_cents(order_data["subtotal"]),
        total_discounts_cents: extract_money_cents(order_data["discountTotal"]),
        total_shipping_cents: extract_money_cents(order_data["shippingTotal"]),
        total_tax_cents: extract_money_cents(order_data["taxTotal"]),
        total_price_cents: extract_money_cents(order_data["grandTotal"]),
        processed_at: parse_datetime(order_data["createdOn"]),
        cancelled_at: map_fulfillment_status(order_data["fulfillmentStatus"]) == "CANCELED" ? parse_datetime(order_data["modifiedOn"]) : nil,
        cancel_reason: map_fulfillment_status(order_data["fulfillmentStatus"]) == "CANCELED" ? "Cancelled in Squarespace" : nil,
        tags: build_tags(order_data),
        note: build_notes(order_data),
        raw_payload: order_data
      )

      order.save!

      # Update shipping address
      if order_data["shippingAddress"]
        import_shipping_address(order, order_data["shippingAddress"])
      else
        order.shipping_address&.destroy
      end

      # Resync order items
      if order_data["lineItems"]
        resync_order_items(order, order_data["lineItems"])
      end

      Rails.logger.info "Successfully resynced order #{order.display_name} (ID: #{order.id})"
      order
    end
  end

  def import_shipping_address(order, address_data)
    shipping_address = order.shipping_address || order.build_shipping_address

    shipping_address.assign_attributes(
      first_name: address_data["firstName"],
      last_name: address_data["lastName"],
      company: nil, # Squarespace doesn't provide company in their API response
      name: "#{address_data['firstName']} #{address_data['lastName']}".strip,
      phone: address_data["phone"],
      address1: address_data["address1"],
      address2: address_data["address2"],
      city: address_data["city"],
      province: address_data["state"],
      province_code: address_data["state"], # Squarespace uses state abbreviations
      postal_code: address_data["postalCode"],
      country_code: address_data["countryCode"],
      country: CountryConfig.country_name(address_data["countryCode"])
    )

    shipping_address.save!
  end

  def import_order_items(order, line_items_data)
    line_items_data.each do |item_data|
      # Only create items for physical products that require fulfillment
      next unless item_data["lineItemType"] == "PHYSICAL_PRODUCT"

      create_order_item(order, item_data)
    end
  end

  def resync_order_items(order, line_items_data)
    squarespace_line_ids = line_items_data
      .select { |item| item["lineItemType"] == "PHYSICAL_PRODUCT" }
      .map { |item| item["id"] }

    # Soft delete order items that no longer exist in Squarespace
    order.order_items.active.where.not(external_line_id: squarespace_line_ids).each do |item|
      item.soft_delete!
      Rails.logger.info "Soft deleted order item: #{item.display_name} (no longer exists in Squarespace)"
    end

    line_items_data.each do |item_data|
      # Only process physical products
      next unless item_data["lineItemType"] == "PHYSICAL_PRODUCT"

      external_line_id = item_data["id"]

      # Find existing order item or create new one
      order_item = order.order_items.find_by(external_line_id: external_line_id)

      if order_item
        # Update existing order item
        update_order_item(order_item, item_data)
      else
        # Create new order item
        create_order_item(order, item_data)
      end
    end
  end

  def create_order_item(order, item_data)
    # Build variant title from variant options
    variant_title = build_variant_title(item_data["variantOptions"])

    order_item = order.order_items.new(
      external_line_id: item_data["id"],
      external_product_id: item_data["productId"],
      external_variant_id: item_data["variantId"],
      title: item_data["productName"],
      sku: item_data["sku"],
      variant_title: variant_title,
      quantity: item_data["quantity"],
      price_cents: extract_money_cents(item_data["unitPricePaid"]),
      total_cents: extract_money_cents(item_data["unitPricePaid"]) * item_data["quantity"],
      discount_amount_cents: 0, # Squarespace doesn't provide line-level discounts
      tax_amount_cents: 0, # Squarespace doesn't provide line-level tax
      taxes_included: item_data.dig("priceTaxInterpretation") == "INCLUSIVE",
      requires_shipping: item_data["lineItemType"] == "PHYSICAL_PRODUCT",
      raw_payload: item_data
    )

    order_item.save!

    Rails.logger.info "Created order item: #{order_item.display_name}"
    order_item
  end

  def update_order_item(order_item, item_data)
    # Build variant title from variant options
    variant_title = build_variant_title(item_data["variantOptions"])

    order_item.assign_attributes(
      external_product_id: item_data["productId"],
      external_variant_id: item_data["variantId"],
      title: item_data["productName"],
      sku: item_data["sku"],
      variant_title: variant_title,
      quantity: item_data["quantity"],
      price_cents: extract_money_cents(item_data["unitPricePaid"]),
      total_cents: extract_money_cents(item_data["unitPricePaid"]) * item_data["quantity"],
      discount_amount_cents: 0,
      tax_amount_cents: 0,
      taxes_included: item_data.dig("priceTaxInterpretation") == "INCLUSIVE",
      requires_shipping: item_data["lineItemType"] == "PHYSICAL_PRODUCT",
      raw_payload: item_data
    )

    order_item.save!
    Rails.logger.info "Updated order item: #{order_item.display_name}"
  end

  def build_variant_title(variant_options)
    return nil if variant_options.blank?

    variant_options.map { |opt| opt["value"] }.join(" / ")
  end

  def extract_currency(order_data)
    # Squarespace includes currency in each money object
    # Try to get it from grandTotal first, then fall back to subtotal
    order_data.dig("grandTotal", "currency") ||
      order_data.dig("subtotal", "currency") ||
      "USD"
  end

  def extract_money_cents(money_hash)
    return 0 if money_hash.blank?

    value = money_hash["value"]
    return 0 if value.blank?

    # Squarespace returns decimal strings like "55.00"
    # Convert to cents (integer)
    (BigDecimal(value) * 100).to_i
  end

  def map_fulfillment_status(status)
    # Squarespace: PENDING, FULFILLED, CANCELED
    # Our system uses similar states
    case status
    when "PENDING"
      "unfulfilled"
    when "FULFILLED"
      "fulfilled"
    when "CANCELED"
      "cancelled"
    else
      "unfulfilled"
    end
  end

  def build_tags(order_data)
    tags = []
    tags << "squarespace" # Platform identifier
    tags << "test-order" if order_data["testmode"] == true
    tags << order_data["channel"] if order_data["channel"].present?
    tags.compact
  end

  def build_notes(order_data)
    notes = []

    # Add internal notes if present
    if order_data["internalNotes"].present?
      notes << "Internal Notes:"
      order_data["internalNotes"].each do |note|
        notes << "- #{note['content']}"
      end
    end

    # Add form submissions if present
    if order_data["formSubmission"].present?
      notes << "\nForm Submissions:" if notes.any?
      order_data["formSubmission"].each do |form|
        notes << "#{form['label']}: #{form['value']}"
      end
    end

    notes.join("\n").presence
  end

  def parse_datetime(datetime_string)
    return nil if datetime_string.blank?
    Time.zone.parse(datetime_string)
  rescue ArgumentError => e
    Rails.logger.warn "Failed to parse datetime: #{datetime_string} - #{e.message}"
    nil
  end
end

