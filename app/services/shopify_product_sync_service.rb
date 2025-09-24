class ShopifyProductSyncService
  attr_reader :store, :session

  def initialize(store)
    @store = store
    @session = ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  def sync_all_products
    products_synced = 0
    variants_synced = 0

    Rails.logger.info "Fetching products from Shopify for store: #{store.name}"

    # Create GraphQL client
    client = ShopifyAPI::Clients::Graphql::Admin.new(session: session)

    # GraphQL query to fetch products with variants
    query = build_products_query

    # Fetch products with pagination
    has_next_page = true
    after_cursor = nil

    while has_next_page
      variables = { first: 50 }
      variables[:after] = after_cursor if after_cursor

      response = client.query(query: query, variables: variables)

      if response.body.dig("data", "products")
        products_data = response.body["data"]["products"]

        # Process each product
        products_data["edges"].each do |edge|
          product_data = edge["node"]
          result = sync_product(product_data)

          products_synced += 1 if result[:product_created_or_updated]
          variants_synced += result[:variants_synced]
        end

        # Check for next page
        page_info = products_data["pageInfo"]
        has_next_page = page_info["hasNextPage"]
        after_cursor = page_info["endCursor"] if has_next_page
      else
        Rails.logger.error "Failed to fetch products: #{response.body}"
        break
      end
    end

    {
      products_synced: products_synced,
      variants_synced: variants_synced
    }
  end

  private

  def sync_product(product_data)
    external_id = extract_id_from_gid(product_data["id"])

    Rails.logger.info "Syncing product: #{product_data['title']} (ID: #{external_id})"

    # Find or create product
    product = store.products.find_or_initialize_by(external_id: external_id)

    # Map Shopify data to our product fields
    product.assign_attributes(
      title: product_data["title"],
      description: product_data["description"],
      description_html: product_data["descriptionHtml"],
      handle: product_data["handle"],
      product_type: product_data["productType"],
      vendor: product_data["vendor"],
      tags: product_data["tags"] || [],
      status: map_product_status(product_data["status"]),
      published_at: product_data["publishedAt"] ? Time.parse(product_data["publishedAt"]) : nil,
      options: map_product_options(product_data["options"]),
      featured_image_url: extract_featured_image(product_data),
      metadata: {
        shopify_data: product_data.except("variants"),
        synced_at: Time.current
      }
    )

    product_created_or_updated = product.changed? || product.new_record?

    Rails.logger.info "Saving product: #{product.title} (#{product_created_or_updated ? 'CHANGED' : 'NO CHANGES'})"
    product.save!

    # Sync variants
    Rails.logger.info "Starting variant sync for product: #{product.title}"
    variants_synced = sync_product_variants(product, product_data["variants"])
    Rails.logger.info "Completed variant sync for product: #{product.title}. Synced #{variants_synced} variants"

    {
      product_created_or_updated: product_created_or_updated,
      variants_synced: variants_synced
    }
  end

  def sync_product_variants(product, variants_data)
    return 0 unless variants_data && variants_data["edges"]

    variants_synced = 0

    Rails.logger.info "Processing #{variants_data['edges'].count} variants for product: #{product.title}"

    variants_data["edges"].each_with_index do |edge, index|
      variant_data = edge["node"]
      external_variant_id = extract_id_from_gid(variant_data["id"])

      Rails.logger.info "=== Processing variant #{index + 1}/#{variants_data['edges'].count} ==="
      Rails.logger.info "Variant title: #{variant_data['title']}"
      Rails.logger.info "Variant ID: #{external_variant_id}"
      Rails.logger.info "Full variant data: #{variant_data.inspect}"

      # Find or create variant
      variant = product.product_variants.find_or_initialize_by(external_variant_id: external_variant_id)
      Rails.logger.info "Variant found/created: #{variant.new_record? ? 'NEW' : 'EXISTING'} (DB ID: #{variant.id})"

      # Extract and validate price
      price_value = variant_data["price"]
      Rails.logger.info "Raw price value: #{price_value.inspect} (type: #{price_value.class})"

      # Handle Shopify Money type - price should be a string like "10.00"
      parsed_price = case price_value
      when String
                      price_value.to_f
      when Numeric
                      price_value.to_f
      when Hash
                      # If it's a Money object with amount field
                      price_value["amount"]&.to_f || 0.0
      else
                      0.0
      end

      Rails.logger.info "Parsed price: #{parsed_price} (type: #{parsed_price.class})"

      # Skip variants with invalid prices
      if parsed_price <= 0
        Rails.logger.warn "Skipping variant #{variant_data['title']} - invalid price: #{price_value.inspect}"
        next
      end

      # Map Shopify variant data
      variant.assign_attributes(
        title: variant_data["title"],
        price: parsed_price,
        compare_at_price: variant_data["compareAtPrice"]&.to_f,
        sku: variant_data["sku"],
        barcode: variant_data["barcode"],
        position: variant_data["position"] || 1,
        available_for_sale: variant_data["availableForSale"],
        weight: extract_weight(variant_data),
        weight_unit: extract_weight_unit(variant_data),
        requires_shipping: variant_data.dig("inventoryItem", "requiresShipping"),
        selected_options: map_variant_options(variant_data["selectedOptions"]),
        image_url: extract_variant_image(variant_data),
        metadata: {
          shopify_data: variant_data,
          synced_at: Time.current
        }
      )

      Rails.logger.info "Variant attributes assigned. Price: #{variant.price}, Valid: #{variant.valid?}"
      if variant.errors.any?
        Rails.logger.error "Variant validation errors: #{variant.errors.full_messages.join(', ')}"
      end

      if variant.changed? || variant.new_record?
        Rails.logger.info "Saving variant: #{variant.title} (changed: #{variant.changed?}, new: #{variant.new_record?})"
        begin
          variant.save!
          variants_synced += 1
          Rails.logger.info "✅ Variant saved successfully! DB ID: #{variant.id}"
        rescue => e
          Rails.logger.error "❌ Failed to save variant: #{e.message}"
          Rails.logger.error "Variant errors: #{variant.errors.full_messages.join(', ')}" if variant.errors.any?
          raise e
        end
      else
        Rails.logger.info "⏭️  Variant unchanged, skipping save"
      end
    end

    variants_synced
  end

  def build_products_query
    # Validated GraphQL query using Shopify MCP tools
    <<~GRAPHQL
      query GetProductsForSync($first: Int!, $after: String) {
        products(first: $first, after: $after) {
          edges {
            cursor
            node {
              id
              title
              description
              descriptionHtml
              handle
              productType
              vendor
              tags
              status
              publishedAt
              createdAt
              updatedAt
              options {
                id
                name
                position
                values
              }
              featuredMedia {
                ... on MediaImage {
                  image {
                    url
                    altText
                    width
                    height
                  }
                }
              }
              variants(first: 250) {
                edges {
                  node {
                    id
                    title
                    price
                    compareAtPrice
                    sku
                    barcode
                    position
                    availableForSale
                    createdAt
                    updatedAt
                    inventoryItem {
                      requiresShipping
                      measurement {
                        weight {
                          value
                          unit
                        }
                      }
                    }
                    selectedOptions {
                      name
                      value
                    }
                    image {
                      url
                      altText
                      width
                      height
                    }
                  }
                }
              }
            }
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    GRAPHQL
  end

  # Helper methods for data extraction and mapping

  def extract_id_from_gid(gid)
    gid.split("/").last.to_i
  end

  def map_product_status(shopify_status)
    case shopify_status&.downcase
    when "active"
      "active"
    when "archived"
      "archived"
    else
      "draft"
    end
  end

  def map_product_options(options_data)
    return [] unless options_data

    options_data.map do |option|
      {
        "name" => option["name"],
        "values" => option["values"] || []
      }
    end
  end

  def map_variant_options(selected_options_data)
    return [] unless selected_options_data

    selected_options_data.map do |option|
      {
        "name" => option["name"],
        "value" => option["value"]
      }
    end
  end

  def extract_featured_image(product_data)
    featured_media = product_data["featuredMedia"]
    return nil unless featured_media&.dig("image", "url")

    featured_media["image"]["url"]
  end

  def extract_variant_image(variant_data)
    image_data = variant_data["image"]
    return nil unless image_data&.dig("url")

    image_data["url"]
  end

  def extract_weight(variant_data)
    weight_data = variant_data.dig("inventoryItem", "measurement", "weight")
    return nil unless weight_data

    weight_data["value"]
  end

  def extract_weight_unit(variant_data)
    weight_data = variant_data.dig("inventoryItem", "measurement", "weight")
    return "kg" unless weight_data

    case weight_data["unit"]&.downcase
    when "grams"
      "g"
    when "kilograms"
      "kg"
    when "pounds"
      "lb"
    when "ounces"
      "oz"
    else
      "kg"
    end
  end
end
