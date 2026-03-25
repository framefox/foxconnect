class ShopifyProductSyncService
  attr_reader :store, :session

  def initialize(store)
    @store = store

    unless store.active?
      raise ShopifyIntegration::InactiveStoreError, "Cannot sync products for inactive store: #{store.name}"
    end

    @session = ShopifyAPI::Auth::Session.new(
      shop: store.shopify_domain,
      access_token: store.shopify_token
    )
  end

  def sync_all_products
    result = base_result
    synced_at = Time.current
    seen_product_external_ids = []
    seen_variant_ids_by_product = {}
    full_reconciliation_completed = true

    Rails.logger.info "Fetching products from Shopify for store: #{store.name}"

    has_next_page = true
    after_cursor = nil

    while has_next_page
      response = graphql_client.query(
        query: build_products_query,
        variables: {
          first: 50,
          after: after_cursor
        }.compact
      )

      products_data = response.body.dig("data", "products")

      unless products_data
        full_reconciliation_completed = false
        add_failure!(result, "Failed to fetch products: #{response.body}")
        Rails.logger.error "Failed to fetch products: #{response.body}"
        break
      end

      products_data["edges"].each do |edge|
        product_data = edge["node"]

        begin
          product_data, variants_complete = hydrate_product_variants(product_data)
          sync_result = sync_product(product_data, synced_at: synced_at)

          merge_sync_result!(result, sync_result)
          seen_product_external_ids << sync_result[:product].external_id.to_s
          seen_variant_ids_by_product[sync_result[:product].id] = sync_result[:seen_variant_ids]

          unless variants_complete
            full_reconciliation_completed = false
            add_failure!(
              result,
              "Product #{sync_result[:product].external_id} variant pagination was incomplete; archival skipped for this full sync"
            )
          end
        rescue => e
          full_reconciliation_completed = false
          external_id = extract_id_from_gid(product_data["id"])
          add_failure!(result, "Failed to sync product #{external_id}: #{e.message}")
          Rails.logger.error "Failed to sync product #{product_data['title']} (ID: #{external_id}): #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
        end
      end

      page_info = products_data["pageInfo"] || {}
      has_next_page = page_info["hasNextPage"]
      after_cursor = page_info["endCursor"] if has_next_page
    end

    if full_reconciliation_completed
      seen_variant_ids_by_product.each do |product_id, seen_variant_ids|
        product = store.products.find_by(id: product_id)
        next unless product

        archive_missing_variants_for_product(product, seen_variant_ids, removed_at: synced_at, result: result)
      end

      archive_missing_products(seen_product_external_ids, removed_at: synced_at, result: result)
    else
      Rails.logger.warn "Skipping product/variant archival for store #{store.name} because the sync was incomplete"
    end

    finalize_result(result, full_reconciliation_completed: full_reconciliation_completed)
  end

  def sync_single_product(product_id)
    synced_at = Time.current
    result = base_result
    status, payload = fetch_single_product(product_id)
    full_reconciliation_completed = false

    case status
    when :ok
      product_data, variants_complete = hydrate_product_variants(payload)
      sync_result = sync_product(product_data, synced_at: synced_at)
      merge_sync_result!(result, sync_result)

      if variants_complete
        archive_missing_variants_for_product(sync_result[:product], sync_result[:seen_variant_ids], removed_at: synced_at, result: result)
        full_reconciliation_completed = true
      else
        add_failure!(
          result,
          "Variant pagination was incomplete for product #{sync_result[:product].external_id}; missing variants were not archived"
        )
      end
    when :missing
      product = store.products.find_by(external_id: product_id.to_s)
      if product
        archive_product(product, removed_at: synced_at, result: result)
      else
        add_failure!(result, "Product #{product_id} does not exist in Shopify or locally")
      end
      result[:product_missing] = true
      full_reconciliation_completed = true
    when :error
      raise StandardError, payload
    end

    finalize_result(result, full_reconciliation_completed: full_reconciliation_completed)
  end

  def sync_specific_products(product_ids)
    aggregate_result = base_result

    Rails.logger.info "Fetching #{product_ids.count} specific products from Shopify for store: #{store.name}"
    Rails.logger.info "Product IDs: #{product_ids.join(', ')}"

    product_ids.each do |product_id|
      begin
        merge_sync_result!(aggregate_result, sync_single_product(product_id))
      rescue => e
        add_failure!(aggregate_result, "Failed to sync product #{product_id}: #{e.message}")
        Rails.logger.error "Failed to sync product #{product_id}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
      end
    end

    finalize_result(aggregate_result, full_reconciliation_completed: false)
  end

  private

  def graphql_client
    @graphql_client ||= ShopifyAPI::Clients::Graphql::Admin.new(session: session)
  end

  def base_result
    {
      products_updated: 0,
      variants_updated: 0,
      products_archived: 0,
      variants_archived: 0,
      products_reactivated: 0,
      variants_reactivated: 0,
      failures: [],
      product_missing: false
    }
  end

  def finalize_result(result, full_reconciliation_completed:)
    result[:full_reconciliation_completed] = full_reconciliation_completed
    result[:products_synced] = result[:products_updated]
    result[:variants_synced] = result[:variants_updated]
    result[:products_failed] = result[:failures].count
    result
  end

  def add_failure!(result, message)
    result[:failures] << message
  end

  def merge_sync_result!(target, source)
    target[:products_updated] += source[:products_updated].to_i
    target[:variants_updated] += source[:variants_updated].to_i
    target[:products_archived] += source[:products_archived].to_i
    target[:variants_archived] += source[:variants_archived].to_i
    target[:products_reactivated] += source[:products_reactivated].to_i
    target[:variants_reactivated] += source[:variants_reactivated].to_i
    target[:product_missing] ||= source[:product_missing]
    target[:failures].concat(Array(source[:failures]))
  end

  def fetch_single_product(product_id)
    response = graphql_client.query(
      query: build_single_product_query,
      variables: { id: build_product_gid(product_id) }
    )

    product_data = response.body.dig("data", "product")
    return [ :ok, product_data ] if product_data.present?
    return [ :missing, nil ] if product_missing_response?(response.body)

    [ :error, "Failed to fetch product #{product_id}: #{response.body}" ]
  end

  def product_missing_response?(body)
    body.dig("data", "product").nil? && (
      body["errors"].blank? ||
      Array(body["errors"]).all? { |error| error["message"].to_s.match?(/not found|does not exist|invalid id/i) }
    )
  end

  def build_product_gid(product_id)
    "gid://shopify/Product/#{product_id}"
  end

  def hydrate_product_variants(product_data)
    hydrated_product = product_data.deep_dup
    variants_data = hydrated_product["variants"] || {}
    all_edges = Array(variants_data["edges"]).dup
    page_info = variants_data["pageInfo"] || {}
    variants_complete = true

    while page_info["hasNextPage"]
      begin
        response = graphql_client.query(
          query: build_product_variants_page_query,
          variables: {
            id: hydrated_product["id"],
            first: 250,
            after: page_info["endCursor"]
          }
        )

        paged_variants = response.body.dig("data", "product", "variants")

        unless paged_variants
          variants_complete = false
          Rails.logger.error "Failed to fetch additional variants for product #{hydrated_product['id']}: #{response.body}"
          break
        end

        all_edges.concat(Array(paged_variants["edges"]))
        page_info = paged_variants["pageInfo"] || {}
      rescue => e
        variants_complete = false
        Rails.logger.error "Variant pagination failed for product #{hydrated_product['id']}: #{e.message}"
        Rails.logger.error e.backtrace.first(5).join("\n")
        break
      end
    end

    hydrated_product["variants"] = {
      "edges" => all_edges,
      "pageInfo" => page_info
    }

    [ hydrated_product, variants_complete ]
  end

  def sync_product(product_data, synced_at:)
    external_id = extract_id_from_gid(product_data["id"]).to_s

    Rails.logger.info "Syncing product: #{product_data['title']} (ID: #{external_id})"

    product = store.products.find_or_initialize_by(external_id: external_id)
    is_new_product = product.new_record?
    product_reactivated = product.removed_from_source?

    product.assign_attributes(
      title: product_data["title"],
      handle: product_data["handle"],
      product_type: product_data["productType"],
      vendor: product_data["vendor"],
      tags: product_data["tags"] || [],
      status: map_product_status(product_data["status"]),
      published_at: product_data["publishedAt"] ? Time.parse(product_data["publishedAt"]) : nil,
      options: map_product_options(product_data["options"]),
      featured_image_url: extract_featured_image(product_data),
      removed_from_source_at: nil,
      last_seen_in_source_at: synced_at,
      metadata: {
        shopify_data: product_data.except("variants"),
        synced_at: synced_at
      }
    )

    if is_new_product && store.fulfill_new_products
      product.fulfilment_active = true
      Rails.logger.info "Auto-enabling fulfillment for new product: #{product.title}"
    end

    products_updated = (product.changed? || product.new_record?) ? 1 : 0

    Rails.logger.info "Saving product: #{product.title} (#{products_updated.positive? ? 'CHANGED' : 'NO CHANGES'})"
    product.save!

    variant_result = sync_product_variants(product, product_data["variants"], synced_at: synced_at)

    {
      product: product,
      seen_variant_ids: variant_result[:seen_variant_ids],
      products_updated: products_updated,
      variants_updated: variant_result[:variants_updated],
      products_reactivated: product_reactivated ? 1 : 0,
      variants_reactivated: variant_result[:variants_reactivated],
      products_archived: 0,
      variants_archived: 0,
      failures: []
    }
  end

  def sync_product_variants(product, variants_data, synced_at:)
    return { variants_updated: 0, variants_reactivated: 0, seen_variant_ids: [] } unless variants_data && variants_data["edges"]

    variants_updated = 0
    variants_reactivated = 0
    seen_variant_ids = []

    Rails.logger.info "Processing #{variants_data['edges'].count} variants for product: #{product.title}"

    existing_positions = product.product_variants.pluck(:position)
    next_position = existing_positions.any? ? existing_positions.max + 1 : 1

    variants_data["edges"].each_with_index do |edge, index|
      variant_data = edge["node"]
      external_variant_id = extract_id_from_gid(variant_data["id"]).to_s
      seen_variant_ids << external_variant_id

      Rails.logger.info "=== Processing variant #{index + 1}/#{variants_data['edges'].count} ==="
      Rails.logger.info "Variant title: #{variant_data['title']}"
      Rails.logger.info "Variant ID: #{external_variant_id}"

      variant = product.product_variants.find_or_initialize_by(external_variant_id: external_variant_id)
      is_new_variant = variant.new_record?
      variant_reactivated = variant.removed_from_source?
      Rails.logger.info "Variant found/created: #{is_new_variant ? 'NEW' : 'EXISTING'} (DB ID: #{variant.id})"

      parsed_price = parse_price(variant_data["price"], variant_data["title"])
      shopify_position = variant_data["position"]
      variant_position = if variant.new_record?
        if shopify_position && !existing_positions.include?(shopify_position)
          shopify_position
        else
          position_to_use = next_position
          next_position += 1
          existing_positions << position_to_use
          position_to_use
        end
      else
        variant.position
      end

      Rails.logger.info "Position assignment: Shopify=#{shopify_position}, Using=#{variant_position}"

      variant.assign_attributes(
        title: variant_data["title"],
        price: parsed_price,
        compare_at_price: variant_data["compareAtPrice"]&.to_f,
        sku: variant_data["sku"],
        barcode: variant_data["barcode"],
        position: variant_position,
        available_for_sale: variant_data["availableForSale"],
        weight: extract_weight(variant_data),
        weight_unit: extract_weight_unit(variant_data),
        requires_shipping: variant_data.dig("inventoryItem", "requiresShipping"),
        selected_options: map_variant_options(variant_data["selectedOptions"]),
        image_url: extract_variant_image(variant_data),
        removed_from_source_at: nil,
        last_seen_in_source_at: synced_at,
        metadata: {
          shopify_data: variant_data,
          synced_at: synced_at
        }
      )

      if is_new_variant && store.fulfill_new_products
        variant.fulfilment_active = true
        Rails.logger.info "Auto-enabling fulfillment for new variant: #{variant.title}"
      end

      Rails.logger.info "Variant attributes assigned. Price: #{variant.price}, Valid: #{variant.valid?}"
      if variant.errors.any?
        Rails.logger.error "Variant validation errors: #{variant.errors.full_messages.join(', ')}"
      end

      if variant.changed? || variant.new_record?
        Rails.logger.info "Saving variant: #{variant.title} (changed: #{variant.changed?}, new: #{variant.new_record?})"
        variant.save!
        variants_updated += 1
      else
        Rails.logger.info "⏭️  Variant unchanged, skipping save"
      end

      variants_reactivated += 1 if variant_reactivated
    end

    {
      variants_updated: variants_updated,
      variants_reactivated: variants_reactivated,
      seen_variant_ids: seen_variant_ids
    }
  end

  def archive_missing_variants_for_product(product, seen_variant_ids, removed_at:, result:)
    variants_to_archive = product.product_variants.present_in_source.where.not(external_variant_id: seen_variant_ids.map(&:to_s))

    variants_to_archive.find_each do |variant|
      result[:variants_archived] += 1 if variant.archive_from_source!(timestamp: removed_at)
    end
  end

  def archive_missing_products(seen_product_external_ids, removed_at:, result:)
    products_to_archive = if seen_product_external_ids.any?
      store.products.present_in_source.where.not(external_id: seen_product_external_ids.map(&:to_s))
    else
      store.products.present_in_source
    end

    products_to_archive.find_each do |product|
      archive_product(product, removed_at: removed_at, result: result)
    end
  end

  def archive_product(product, removed_at:, result:)
    archive_result = product.archive_from_source!(timestamp: removed_at)
    result[:products_archived] += 1 if archive_result[:product_archived]
    result[:variants_archived] += archive_result[:variants_archived]
  end

  def parse_price(price_value, variant_title)
    Rails.logger.info "Raw price value: #{price_value.inspect} (type: #{price_value.class})"

    parsed_price = case price_value
    when String, Numeric
      price_value.to_f
    when Hash
      price_value["amount"]&.to_f || 0.0
    else
      0.0
    end

    if parsed_price < 0
      Rails.logger.warn "Variant #{variant_title} has negative price: #{price_value.inspect}, setting to 0"
      0.0
    else
      Rails.logger.info "Parsed price: #{parsed_price} (type: #{parsed_price.class})"
      parsed_price
    end
  end

  def build_products_query
    <<~GRAPHQL
      query GetProductsForSync($first: Int!, $after: String) {
        products(first: $first, after: $after) {
          edges {
            cursor
            node {
              #{product_node_selection}
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

  def build_single_product_query
    <<~GRAPHQL
      query GetProductByID($id: ID!) {
        product(id: $id) {
          #{product_node_selection}
        }
      }
    GRAPHQL
  end

  def build_product_variants_page_query
    <<~GRAPHQL
      query GetProductVariantsPage($id: ID!, $first: Int!, $after: String) {
        product(id: $id) {
          variants(first: $first, after: $after) {
            edges {
              node {
                #{variant_node_selection}
              }
            }
            pageInfo {
              hasNextPage
              endCursor
            }
          }
        }
      }
    GRAPHQL
  end

  def product_node_selection
    <<~GRAPHQL
      id
      title
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
            #{variant_node_selection}
          }
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    GRAPHQL
  end

  def variant_node_selection
    <<~GRAPHQL
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
        id
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
    GRAPHQL
  end

  def extract_id_from_gid(gid)
    gid.to_s.split("/").last.to_i
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
