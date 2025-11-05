class SquarespaceProductSyncService
  attr_reader :store, :api_client

  def initialize(store)
    @store = store

    # Block sync for inactive stores
    unless store.active?
      raise StandardError, "Cannot sync products for inactive store: #{store.name}"
    end

    @api_client = store.squarespace_api_client
    raise StandardError, "No API client available for store: #{store.name}" unless @api_client
  end

  def sync_all_products
    products_synced = 0
    variants_synced = 0
    products_skipped = 0

    Rails.logger.info "Fetching products from Squarespace for store: #{store.name}"

    # Fetch products with cursor-based pagination
    cursor = nil
    has_more = true

    while has_more
      begin
        Rails.logger.info "Calling API with cursor: #{cursor.inspect}"
        response = api_client.get_products(cursor: cursor)
        Rails.logger.info "API response keys: #{response.keys.inspect}"
        Rails.logger.info "Full API response: #{response.inspect[0..500]}"
        
        products_data = response["products"] || []
        pagination = response["pagination"] || {}

        Rails.logger.info "Fetched #{products_data.count} products in this batch"
        
        if products_data.any?
          Rails.logger.info "First product keys: #{products_data.first.keys.inspect}"
          Rails.logger.info "First product sample: #{products_data.first.inspect[0..300]}"
        end

        # Process each product
        products_data.each do |product_data|
          # Only sync PHYSICAL products
          unless product_data["type"] == "PHYSICAL"
            Rails.logger.info "Skipping non-physical product: #{product_data['name']} (type: #{product_data['type']})"
            products_skipped += 1
            next
          end

          begin
            result = sync_product(product_data)
            products_synced += 1 if result[:product_created_or_updated]
            variants_synced += result[:variants_synced]
          rescue => e
            Rails.logger.error "Failed to sync product #{product_data['id']}: #{e.message}"
            Rails.logger.error e.backtrace.join("\n")
            # Continue with next product
          end
        end

        # Check for next page
        cursor = pagination["nextPageCursor"]
        has_more = pagination["hasNextPage"] || false

      rescue => e
        Rails.logger.error "Failed to fetch products: #{e.message}"
        break
      end
    end

    Rails.logger.info "Sync completed: #{products_synced} products synced, #{variants_synced} variants synced, #{products_skipped} products skipped"

    {
      products_synced: products_synced,
      variants_synced: variants_synced,
      products_skipped: products_skipped
    }
  end

  # Sync specific products by their Squarespace IDs
  def sync_specific_products(product_ids)
    products_synced = 0
    variants_synced = 0

    Rails.logger.info "Fetching #{product_ids.count} specific products from Squarespace for store: #{store.name}"

    product_ids.each do |product_id|
      begin
        product_data = api_client.get_product(product_id)
        
        # Only sync PHYSICAL products
        unless product_data["type"] == "PHYSICAL"
          Rails.logger.info "Skipping non-physical product: #{product_data['name']} (type: #{product_data['type']})"
          next
        end

        result = sync_product(product_data)
        products_synced += 1 if result[:product_created_or_updated]
        variants_synced += result[:variants_synced]
      rescue => e
        Rails.logger.error "Failed to sync product #{product_id}: #{e.message}"
      end
    end

    {
      products_synced: products_synced,
      variants_synced: variants_synced
    }
  end

  private

  def sync_product(product_data)
    external_id = product_data["id"]

    Rails.logger.info "=== SYNCING PRODUCT ==="
    Rails.logger.info "Product ID: #{external_id}"
    Rails.logger.info "Product keys: #{product_data.keys.inspect}"
    Rails.logger.info "Product name: #{product_data['name'].inspect}"
    Rails.logger.info "Product URL: #{product_data['url'].inspect}"
    Rails.logger.info "Product urlSlug: #{product_data['urlSlug'].inspect}"
    Rails.logger.info "Product type: #{product_data['type'].inspect}"
    Rails.logger.info "Full product data: #{product_data.inspect}"

    # Skip products with no name
    if product_data["name"].blank?
      Rails.logger.warn "Skipping product #{external_id} - no name provided"
      return { product_created_or_updated: false, variants_synced: 0 }
    end

    # Find or create product
    product = store.products.find_or_initialize_by(external_id: external_id)
    is_new_product = product.new_record?

    # Extract handle - try urlSlug first, then URL, then parameterize name, then fallback to ID
    handle = product_data["urlSlug"].presence ||
             extract_handle_from_url(product_data["url"]) || 
             product_data["name"]&.parameterize || 
             "squarespace-#{product_data['id']}"

    Rails.logger.info "Extracted handle: #{handle}"

    # Map Squarespace data to our product fields
    product.assign_attributes(
      title: product_data["name"],
      handle: handle,
      product_type: product_data["type"],
      vendor: nil, # Squarespace doesn't have vendor concept
      tags: product_data["tags"] || [],
      status: map_product_status(product_data["isVisible"]),
      published_at: product_data["createdOn"] ? Time.parse(product_data["createdOn"]) : nil,
      options: map_product_options(product_data["variants"]),
      featured_image_url: extract_featured_image(product_data),
      images: extract_images(product_data),
      metadata: {
        squarespace_data: product_data.except("variants"),
        description: product_data["description"], # Store description in metadata
        product_type: product_data["type"],
        synced_at: Time.current
      }
    )

    # Apply fulfill_new_products setting for new products
    if is_new_product && store.fulfill_new_products
      product.fulfilment_active = true
      Rails.logger.info "Auto-enabling fulfillment for new product: #{product.title}"
    end

    product_created_or_updated = product.changed? || product.new_record?

    Rails.logger.info "Saving product: #{product.title} (#{product_created_or_updated ? 'CHANGED' : 'NO CHANGES'})"
    product.save!

    # Sync variants
    Rails.logger.info "Starting variant sync for product: #{product.title}"
    variants_synced = sync_product_variants(product, product_data["variants"] || [])
    Rails.logger.info "Completed variant sync for product: #{product.title}. Synced #{variants_synced} variants"

    {
      product_created_or_updated: product_created_or_updated,
      variants_synced: variants_synced
    }
  end

  def sync_product_variants(product, variants_data)
    variants_synced = 0

    Rails.logger.info "Processing #{variants_data.count} variants for product: #{product.title}"

    # Get existing positions to avoid conflicts
    existing_positions = product.product_variants.pluck(:position)
    next_position = existing_positions.any? ? existing_positions.max + 1 : 1

    variants_data.each_with_index do |variant_data, index|
      external_variant_id = variant_data["id"]

      Rails.logger.info "=== Processing variant #{index + 1}/#{variants_data.count} ==="
      Rails.logger.info "Variant SKU: #{variant_data['sku']}"
      Rails.logger.info "Variant ID: #{external_variant_id}"

      # Find or create variant
      variant = product.product_variants.find_or_initialize_by(external_variant_id: external_variant_id)
      is_new_variant = variant.new_record?
      Rails.logger.info "Variant found/created: #{is_new_variant ? 'NEW' : 'EXISTING'} (DB ID: #{variant.id})"

      # Extract and parse price from pricing object
      pricing = variant_data["pricing"] || {}
      base_price = pricing["basePrice"] || {}
      sale_price = pricing["salePrice"] || {}
      
      price_value = base_price["value"]&.to_f || 0.0
      compare_at_price_value = nil
      
      # If on sale, use sale price as compare_at_price
      if pricing["onSale"] && sale_price["value"]
        compare_at_price_value = price_value
        price_value = sale_price["value"].to_f
      end

      Rails.logger.info "Price: #{price_value}, Compare at: #{compare_at_price_value}"

      # Determine position
      variant_position = if variant.new_record?
        position_to_use = next_position
        next_position += 1
        existing_positions << position_to_use
        position_to_use
      else
        variant.position
      end

      # Extract weight
      weight_value = variant_data["weight"]&.to_f
      weight_unit_value = variant_data["weight"] ? "lb" : nil # Squarespace typically uses lbs

      # Build variant title from attributes (e.g., "A2 / Walnut")
      variant_title = build_variant_title(variant_data["attributes"], variant_position)

      # Map variant data
      variant.assign_attributes(
        title: variant_title,
        price: price_value,
        compare_at_price: compare_at_price_value,
        sku: variant_data["sku"],
        barcode: nil, # Squarespace doesn't provide barcode in API
        position: variant_position,
        available_for_sale: true, # Default to true as per plan
        weight: weight_value,
        weight_unit: weight_unit_value,
        requires_shipping: true, # Always true for physical products
        selected_options: map_variant_options(variant_data["attributes"]),
        image_url: extract_variant_image(variant_data, product),
        metadata: {
          squarespace_data: variant_data,
          stock_quantity: variant_data.dig("stock", "quantity"),
          stock_unlimited: variant_data.dig("stock", "unlimited"),
          synced_at: Time.current
        }
      )

      # Apply fulfill_new_products setting for new variants
      if is_new_variant && store.fulfill_new_products
        variant.fulfilment_active = true
        Rails.logger.info "Auto-enabling fulfillment for new variant: #{variant.title}"
      end

      variant_changed = variant.changed? || variant.new_record?
      Rails.logger.info "Saving variant: #{variant.title} (#{variant_changed ? 'CHANGED' : 'NO CHANGES'})"
      
      if variant.save
        variants_synced += 1
      else
        Rails.logger.error "Failed to save variant: #{variant.errors.full_messages.join(', ')}"
      end
    end

    variants_synced
  end

  # Helper methods

  def extract_handle_from_url(url)
    return nil unless url.present?
    
    # Extract slug from URL like "/shop/p/product-name" -> "product-name"
    # or "/product-name" -> "product-name"
    # Remove leading/trailing slashes and get the last segment
    segments = url.strip.split('/').reject(&:empty?)
    segments.last
  end

  def map_product_status(is_visible)
    is_visible ? "active" : "draft"
  end

  def map_product_options(variants_data)
    return [] unless variants_data.present?

    # Extract unique option names from all variants' attributes
    # In Squarespace, attributes is a hash like {"Frame"=>"Black"}
    option_names = Set.new
    
    variants_data.each do |variant|
      attributes = variant["attributes"] || {}
      # attributes is a hash, so keys are the option names
      option_names.merge(attributes.keys)
    end

    option_names.map { |name| { "name" => name, "values" => [] } }
  end

  def extract_featured_image(product_data)
    images = product_data["images"] || []
    first_image = images.first
    first_image ? first_image["url"] : nil
  end

  def extract_images(product_data)
    images = product_data["images"] || []
    images.map { |img| { "url" => img["url"], "alt" => img["altText"] } }
  end

  def map_variant_options(attributes)
    return [] unless attributes.present?

    # In Squarespace, attributes is a hash like {"Frame"=>"Black"}
    # Convert to array of {name, value} objects
    attributes.map do |name, value|
      {
        "name" => name,
        "value" => value
      }
    end
  end

  def extract_variant_image(variant_data, product)
    # Squarespace doesn't have per-variant images in the same way
    # Use the product's first image as fallback
    product.featured_image_url
  end

  def build_variant_title(attributes, position)
    # Build variant title from attributes hash
    # Example: {"Size"=>"A2", "Color"=>"Walnut"} => "A2 / Walnut"
    if attributes.present? && attributes.is_a?(Hash)
      attributes.values.join(" / ")
    else
      "Variant #{position}"
    end
  end
end

