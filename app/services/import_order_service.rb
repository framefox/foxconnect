class ImportOrderService
  attr_reader :store, :order_id, :session

  def initialize(store:, order_id:)
    @store = store
    @order_id = normalize_order_id(order_id)
    @session = ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  def call
    return nil unless store.shopify?

    # Block imports from inactive stores
    unless store.active?
      Rails.logger.warn "Attempted to import order from inactive store: #{store.name}"
      return nil
    end

    Rails.logger.info "Importing order #{order_id} from Shopify store: #{store.name}"

    # Create GraphQL client
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # Build GraphQL query for order
    query = build_order_query
    variables = { id: build_order_gid(order_id) }

    # Fetch order from Shopify
    response = client.query(query: query, variables: variables)

    if response.body.dig("data", "order")
      order_data = response.body["data"]["order"]
      import_order(order_data)
    elsif response.body["errors"]
      Rails.logger.error "GraphQL errors: #{response.body['errors'].inspect}"
      raise StandardError, "GraphQL errors: #{response.body['errors'].map { |e| e['message'] }.join(', ')}"
    else
      Rails.logger.error "Order not found: #{order_id}"
      raise StandardError, "Order not found with ID: #{order_id}"
    end
  end

  def resync_order(existing_order)
    return nil unless store.shopify?

    # Block resyncs from inactive stores
    unless store.active?
      Rails.logger.warn "Attempted to resync order from inactive store: #{store.name}"
      return nil
    end

    Rails.logger.info "Resyncing order #{existing_order.external_id} from Shopify store: #{store.name}"

    # Create GraphQL client
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # Build GraphQL query for order
    query = build_order_query
    variables = { id: build_order_gid(existing_order.external_id) }

    # Fetch order from Shopify
    response = client.query(query: query, variables: variables)

    if response.body.dig("data", "order")
      order_data = response.body["data"]["order"]
      resync_order_data(existing_order, order_data)
    elsif response.body["errors"]
      Rails.logger.error "GraphQL errors: #{response.body['errors'].inspect}"
      raise StandardError, "GraphQL errors: #{response.body['errors'].map { |e| e['message'] }.join(', ')}"
    else
      Rails.logger.error "Order not found: #{existing_order.external_id}"
      raise StandardError, "Order not found with ID: #{existing_order.external_id}"
    end
  end

  private

  def normalize_order_id(id)
    # Extract numeric ID from GID format if provided
    if id.to_s.include?("gid://shopify/Order/")
      id.to_s.split("/").last
    else
      # Remove any # prefix if present (e.g., #1001 -> 1001)
      id.to_s.gsub(/^#+/, "")
    end
  end

  def build_order_gid(id)
    "gid://shopify/Order/#{id}"
  end

  def build_order_query
    <<~GRAPHQL
      query GetOrder($id: ID!) {
        order(id: $id) {
          id
          name
          email
          phone
          currencyCode
          subtotalPriceSet {
            shopMoney {
              amount
              currencyCode
            }
          }
          totalDiscountsSet {
            shopMoney {
              amount
              currencyCode
            }
          }
          totalShippingPriceSet {
            shopMoney {
              amount
              currencyCode
            }
          }
          totalTaxSet {
            shopMoney {
              amount
              currencyCode
            }
          }
          totalPriceSet {
            shopMoney {
              amount
              currencyCode
            }
          }
          processedAt
          cancelledAt
          closedAt
          cancelReason
          tags
          note
          createdAt
          updatedAt
          lineItems(first: 250) {
            edges {
              node {
                id
                title
                variantTitle
                quantity
                fulfillableQuantity
                originalUnitPriceSet {
                  shopMoney {
                    amount
                    currencyCode
                  }
                }
                originalTotalSet {
                  shopMoney {
                    amount
                    currencyCode
                  }
                }
                discountedTotalSet {
                  shopMoney {
                    amount
                    currencyCode
                  }
                }
                totalDiscountSet {
                  shopMoney {
                    amount
                    currencyCode
                  }
                }
                taxLines {
                  priceSet {
                    shopMoney {
                      amount
                      currencyCode
                    }
                  }
                  rate
                  title
                }
          requiresShipping
          sku
          product {
                  id
                  title
                  handle
                }
                variant {
                  id
                  title
                  sku
                  barcode
                }
              }
            }
          }
          shippingAddress {
            firstName
            lastName
            name
            company
            address1
            address2
            city
            province
            provinceCode
            country
            countryCodeV2
            zip
            phone
            latitude
            longitude
          }
        }
      }
    GRAPHQL
  end

  def import_order(order_data)
    created_new_order = false
    order = ActiveRecord::Base.transaction do
      # Check if order already exists
      external_id = extract_id_from_gid(order_data["id"])
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
      currency_code = order_data["currencyCode"]
      if currency_code.blank?
        raise StandardError, "Order currency code is missing from Shopify data"
      end

      # Validate it's a valid currency
      begin
        Money::Currency.new(currency_code)
      rescue Money::Currency::UnknownCurrency
        raise StandardError, "Invalid currency code from Shopify: #{currency_code}"
      end

      # Set country code from shipping address data (before building address association)
      shipping_country_code = order_data.dig("shippingAddress", "countryCodeV2")&.upcase

      # Validate country is supported
      if shipping_country_code.present? && !CountryConfig.supported?(shipping_country_code)
        raise StandardError, "Unsupported country: #{shipping_country_code}. Only NZ and AU orders can be fulfilled."
      end

      # Map order fields
      order.assign_attributes(
        external_number: order_data["name"],
        name: order_data["name"],
        customer_phone: order_data["phone"],
        currency: currency_code,
        country_code: shipping_country_code,
        subtotal_price_cents: (extract_money_amount(order_data, "subtotalPriceSet") * 100).to_i,
        total_discounts_cents: (extract_money_amount(order_data, "totalDiscountsSet") * 100).to_i,
        total_shipping_cents: (extract_money_amount(order_data, "totalShippingPriceSet") * 100).to_i,
        total_tax_cents: (extract_money_amount(order_data, "totalTaxSet") * 100).to_i,
        total_price_cents: (extract_money_amount(order_data, "totalPriceSet") * 100).to_i,
        processed_at: parse_datetime(order_data["processedAt"]),
        cancelled_at: parse_datetime(order_data["cancelledAt"]),
        closed_at: parse_datetime(order_data["closedAt"]),
        cancel_reason: order_data["cancelReason"],
        tags: order_data["tags"] || [],
        note: order_data["note"],
        raw_payload: order_data
      )

      order.save!

      # Import shipping address after order is saved
      if order_data["shippingAddress"]
        import_shipping_address(order, order_data["shippingAddress"])
      end

      # Log import activity for new orders
      unless existing_order
        OrderActivityService.log_activity(
          order: order,
          activity_type: :order_imported,
          title: "Order imported from #{store.platform.humanize}",
          description: "Order #{order.display_name} imported from #{store.name}",
          metadata: {
            source_platform: store.platform,
            external_id: external_id,
            store_name: store.name
          }
        )
      end

      # Import order items
      if order_data["lineItems"]
        import_order_items(order, order_data["lineItems"]["edges"])
      end

      Rails.logger.info "Successfully imported order #{order.display_name} (ID: #{order.id})"
    order
  end

  # Send draft imported email to the user (merchant) only when a new order is created
  if created_new_order && order.present?
    OrderMailer.with(order_id: order.id).draft_imported.deliver_later
  end

  order
end

  def import_shipping_address(order, address_data)
    # Remove existing shipping address if any
    order.shipping_address&.destroy

    shipping_address = order.build_shipping_address(
      first_name: address_data["firstName"],
      last_name: address_data["lastName"],
      name: address_data["name"],
      company: address_data["company"],
      address1: address_data["address1"],
      address2: address_data["address2"],
      city: address_data["city"],
      province: address_data["province"],
      province_code: address_data["provinceCode"],
      country: address_data["country"],
      country_code: address_data["countryCodeV2"],
      postal_code: address_data["zip"],
      phone: address_data["phone"],
      latitude: address_data["latitude"],
      longitude: address_data["longitude"]
    )

    shipping_address.save!
    Rails.logger.info "Imported shipping address for order #{order.display_name}"
  end

  def import_order_items(order, line_items_data)
    # Remove existing order items
    order.order_items.destroy_all

    line_items_data.each do |edge|
      item_data = edge["node"]
      external_line_id = extract_id_from_gid(item_data["id"])
      external_product_id = item_data["product"] ? extract_id_from_gid(item_data["product"]["id"]) : nil
      external_variant_id = item_data["variant"] ? extract_id_from_gid(item_data["variant"]["id"]) : nil

      # Calculate tax amount from tax lines
      tax_amount = 0
      if item_data["taxLines"]
        tax_amount = item_data["taxLines"].sum do |tax_line|
          extract_money_amount(tax_line, "priceSet")
        end
      end

      # Calculate discount amount
      original_total = extract_money_amount(item_data, "originalTotalSet")
      discounted_total = extract_money_amount(item_data, "discountedTotalSet")
      discount_amount = original_total - discounted_total

      order_item = order.order_items.build(
        external_line_id: external_line_id,
        external_product_id: external_product_id,
        external_variant_id: external_variant_id,
        title: item_data["title"],
        variant_title: item_data["variantTitle"],
        quantity: item_data["quantity"],
        price_cents: (extract_money_amount(item_data, "originalUnitPriceSet") * 100).to_i,
        total_cents: (extract_money_amount(item_data, "discountedTotalSet") * 100).to_i,
        discount_amount_cents: (discount_amount * 100).to_i,
        tax_amount_cents: (tax_amount * 100).to_i,
        requires_shipping: item_data["requiresShipping"] || false,
        sku: item_data["sku"] || item_data.dig("variant", "sku"),
        raw_payload: item_data
      )

      order_item.save!

      Rails.logger.info "Imported order item: #{order_item.display_name}"
    end
  end

  def extract_money_amount(data, field_path)
    amount_str = data.dig(field_path, "shopMoney", "amount")
    amount_str ? BigDecimal(amount_str) : BigDecimal(0)
  end

  def extract_id_from_gid(gid)
    gid.to_s.split("/").last
  end

  def parse_datetime(datetime_str)
    return nil unless datetime_str
    Time.parse(datetime_str)
  rescue StandardError => e
    Rails.logger.error "Failed to parse datetime: #{datetime_str} - #{e.message}"
    nil
  end

  def resync_order_data(order, order_data)
    ActiveRecord::Base.transaction do
      Rails.logger.info "Resyncing order #{order.display_name} (ID: #{order.id})"

      # Set country code from shipping address data (before building address association)
      shipping_country_code = order_data.dig("shippingAddress", "countryCodeV2")&.upcase

      # Validate country is supported
      if shipping_country_code.present? && !CountryConfig.supported?(shipping_country_code)
        raise StandardError, "Unsupported country: #{shipping_country_code}. Only NZ and AU orders can be fulfilled."
      end

      # Update order fields
      order.assign_attributes(
        external_number: order_data["name"],
        name: order_data["name"],
        customer_phone: order_data["phone"],
        currency: order_data["currencyCode"],
        country_code: shipping_country_code,
        subtotal_price_cents: (extract_money_amount(order_data, "subtotalPriceSet") * 100).to_i,
        total_discounts_cents: (extract_money_amount(order_data, "totalDiscountsSet") * 100).to_i,
        total_shipping_cents: (extract_money_amount(order_data, "totalShippingPriceSet") * 100).to_i,
        total_tax_cents: (extract_money_amount(order_data, "totalTaxSet") * 100).to_i,
        total_price_cents: (extract_money_amount(order_data, "totalPriceSet") * 100).to_i,
        processed_at: parse_datetime(order_data["processedAt"]),
        cancelled_at: parse_datetime(order_data["cancelledAt"]),
        closed_at: parse_datetime(order_data["closedAt"]),
        cancel_reason: order_data["cancelReason"],
        tags: order_data["tags"] || [],
        note: order_data["note"],
        raw_payload: order_data
      )

      order.save!

      # Update shipping address after order is saved
      if order_data["shippingAddress"]
        import_shipping_address(order, order_data["shippingAddress"])
      else
        # Remove shipping address if it no longer exists in Shopify
        order.shipping_address&.destroy
      end

      # Resync order items
      if order_data["lineItems"]
        resync_order_items(order, order_data["lineItems"]["edges"])
      end

      Rails.logger.info "Successfully resynced order #{order.display_name} (ID: #{order.id})"
      order
    end
  end

  def resync_order_items(order, line_items_data)
    # Get current Shopify line item IDs
    shopify_line_ids = line_items_data.map { |edge| extract_id_from_gid(edge["node"]["id"]) }

    # Soft delete order items that no longer exist in Shopify
    order.order_items.active.where.not(external_line_id: shopify_line_ids).each do |item|
      item.soft_delete!
      Rails.logger.info "Soft deleted order item: #{item.display_name} (no longer exists in Shopify)"
    end

    line_items_data.each do |edge|
      item_data = edge["node"]
      external_line_id = extract_id_from_gid(item_data["id"])
      fulfillable_quantity = (item_data["fulfillableQuantity"] || 0).to_i

      # Find existing order item or create new one
      order_item = order.order_items.find_by(external_line_id: external_line_id)

      if order_item
        # Update existing order item first
        update_order_item(order_item, item_data)

        # Then check if item should be soft deleted (fulfillableQuantity is 0)
        if fulfillable_quantity == 0 && order_item.active?
          order_item.soft_delete!
          Rails.logger.info "Soft deleted order item: #{order_item.display_name} (fulfillableQuantity is 0)"
        elsif fulfillable_quantity > 0 && order_item.deleted?
          # Restore item if it was soft deleted but now has fulfillable quantity
          order_item.restore!
          Rails.logger.info "Restored order item: #{order_item.display_name} (fulfillableQuantity > 0)"
        end
      else
        # Create new order item only if it has fulfillable quantity
        if fulfillable_quantity > 0
          create_order_item(order, item_data)
        else
          # Create and immediately soft delete if fulfillableQuantity is 0
          order_item = create_order_item(order, item_data)
          order_item.soft_delete!
          Rails.logger.info "Created and soft deleted order item: #{order_item.display_name} (fulfillableQuantity is 0)"
        end
      end
    end
  end

  def update_order_item(order_item, item_data)
    external_product_id = item_data["product"] ? extract_id_from_gid(item_data["product"]["id"]) : nil
    external_variant_id = item_data["variant"] ? extract_id_from_gid(item_data["variant"]["id"]) : nil

    # Calculate tax amount from tax lines
    tax_amount = 0
    if item_data["taxLines"]
      tax_amount = item_data["taxLines"].sum do |tax_line|
        extract_money_amount(tax_line, "priceSet")
      end
    end

    # Calculate discount amount
    original_total = extract_money_amount(item_data, "originalTotalSet")
    discounted_total = extract_money_amount(item_data, "discountedTotalSet")
    discount_amount = original_total - discounted_total

    order_item.assign_attributes(
      external_product_id: external_product_id,
      external_variant_id: external_variant_id,
      title: item_data["title"],
      variant_title: item_data["variantTitle"],
      quantity: item_data["quantity"],
      price_cents: (extract_money_amount(item_data, "originalUnitPriceSet") * 100).to_i,
      total_cents: (extract_money_amount(item_data, "discountedTotalSet") * 100).to_i,
      discount_amount_cents: (discount_amount * 100).to_i,
      tax_amount_cents: (tax_amount * 100).to_i,
      requires_shipping: item_data["requiresShipping"] || false,
      sku: item_data["sku"] || item_data.dig("variant", "sku"),
      raw_payload: item_data
    )

    order_item.save!

    # Re-resolve variant associations in case they changed
    order_item.resolve_variant_associations!

    # Save again to persist the resolved associations
    order_item.save! if order_item.changed?

    Rails.logger.info "Updated order item: #{order_item.display_name}"
  end

  def create_order_item(order, item_data)
    external_line_id = extract_id_from_gid(item_data["id"])
    external_product_id = item_data["product"] ? extract_id_from_gid(item_data["product"]["id"]) : nil
    external_variant_id = item_data["variant"] ? extract_id_from_gid(item_data["variant"]["id"]) : nil

    # Calculate tax amount from tax lines
    tax_amount = 0
    if item_data["taxLines"]
      tax_amount = item_data["taxLines"].sum do |tax_line|
        extract_money_amount(tax_line, "priceSet")
      end
    end

    # Calculate discount amount
    original_total = extract_money_amount(item_data, "originalTotalSet")
    discounted_total = extract_money_amount(item_data, "discountedTotalSet")
    discount_amount = original_total - discounted_total

    order_item = order.order_items.build(
      external_line_id: external_line_id,
      external_product_id: external_product_id,
      external_variant_id: external_variant_id,
      title: item_data["title"],
      variant_title: item_data["variantTitle"],
      quantity: item_data["quantity"],
      price_cents: (extract_money_amount(item_data, "originalUnitPriceSet") * 100).to_i,
      total_cents: (extract_money_amount(item_data, "discountedTotalSet") * 100).to_i,
      discount_amount_cents: (discount_amount * 100).to_i,
      tax_amount_cents: (tax_amount * 100).to_i,
      requires_shipping: item_data["requiresShipping"] || false,
      sku: item_data["sku"] || item_data.dig("variant", "sku"),
      raw_payload: item_data
    )

    order_item.save!

    # Explicitly resolve variant associations after save for resync scenarios
    # where products might have been synced after the order was imported
    order_item.resolve_variant_associations!
    order_item.save! if order_item.changed?

    Rails.logger.info "Created new order item: #{order_item.display_name}"
    order_item
  end
end
