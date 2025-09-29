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
          displayFinancialStatus
          displayFulfillmentStatus
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
    ActiveRecord::Base.transaction do
      # Check if order already exists
      external_id = extract_id_from_gid(order_data["id"])
      existing_order = Order.find_by(store: store, external_id: external_id)

      if existing_order
        Rails.logger.info "Order #{external_id} already exists, updating..."
        order = existing_order
      else
        Rails.logger.info "Creating new order #{external_id}..."
        order = Order.new(store: store, external_id: external_id)
      end

      # Map order fields
      order.assign_attributes(
        external_number: order_data["name"],
        name: order_data["name"],
        customer_email: order_data["email"],
        customer_phone: order_data["phone"],
        currency: order_data["currencyCode"],
        subtotal_price: extract_money_amount(order_data, "subtotalPriceSet"),
        total_discounts: extract_money_amount(order_data, "totalDiscountsSet"),
        total_shipping: extract_money_amount(order_data, "totalShippingPriceSet"),
        total_tax: extract_money_amount(order_data, "totalTaxSet"),
        total_price: extract_money_amount(order_data, "totalPriceSet"),
        financial_status: map_financial_status(order_data["displayFinancialStatus"]),
        fulfillment_status: map_fulfillment_status(order_data["displayFulfillmentStatus"]),
        processed_at: parse_datetime(order_data["processedAt"]),
        cancelled_at: parse_datetime(order_data["cancelledAt"]),
        closed_at: parse_datetime(order_data["closedAt"]),
        cancel_reason: order_data["cancelReason"],
        tags: order_data["tags"] || [],
        note: order_data["note"],
        raw_payload: order_data
      )

      order.save!

      # Import shipping address
      if order_data["shippingAddress"]
        import_shipping_address(order, order_data["shippingAddress"])
      end

      # Import order items
      if order_data["lineItems"]
        import_order_items(order, order_data["lineItems"]["edges"])
      end

      Rails.logger.info "Successfully imported order #{order.display_name} (ID: #{order.id})"
      order
    end
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
        price: extract_money_amount(item_data, "originalUnitPriceSet"),
        total: extract_money_amount(item_data, "discountedTotalSet"),
        discount_amount: discount_amount,
        tax_amount: tax_amount,
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

  def map_financial_status(status)
    case status&.downcase
    when "paid"
      "paid"
    when "pending", "authorized"
      "pending"
    when "partially paid"
      "partially_paid"
    when "refunded"
      "refunded"
    when "voided"
      "voided"
    else
      "pending"
    end
  end

  def map_fulfillment_status(status)
    case status&.downcase
    when "fulfilled"
      "fulfilled"
    when "unfulfilled"
      "unfulfilled"
    when "partial", "partially fulfilled"
      "partial"
    when "restocked"
      "restocked"
    when "cancelled"
      "cancelled"
    else
      "unfulfilled"
    end
  end
end
