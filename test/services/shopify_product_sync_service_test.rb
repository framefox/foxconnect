require "test_helper"

class ShopifyProductSyncServiceTest < ActiveSupport::TestCase
  class FakeGraphqlAdminClient
    Response = Struct.new(:body)

    attr_reader :queries

    def initialize(operation_responses)
      @operation_responses = operation_responses.transform_values { |responses| Array(responses).dup }
      @queries = []
    end

    def query(query:, variables: {})
      operation_name = query[/query\s+(\w+)/, 1]
      @queries << { operation_name: operation_name, variables: variables.deep_dup }

      responses = @operation_responses.fetch(operation_name) do
        raise "Unexpected GraphQL operation: #{operation_name}"
      end

      body = responses.shift
      raise "No fake response remaining for #{operation_name}" if body.nil?
      raise body if body.is_a?(Exception)

      Response.new(body.deep_dup)
    end
  end

  test "full sync creates new records, updates titles, and preserves historical order item titles" do
    store = create_store!
    product = create_product!(store: store, external_id: "101", title: "Old Product Title")
    variant = create_variant!(product: product, external_variant_id: "201", title: "Old Variant Title", position: 1)
    order_item = create_order_item!(store: store, product: product, variant: variant, title: "Historic Product Title", variant_title: "Historic Variant Title")

    result = with_fake_shopify_client(store, {
      "GetProductsForSync" => [
        products_response([
          shopify_product_payload(
            id: 101,
            title: "Updated Product Title",
            handle: "updated-product-title",
            variants: [
              shopify_variant_payload(id: 201, title: "Updated Variant Title", position: 1)
            ]
          ),
          shopify_product_payload(
            id: 102,
            title: "Brand New Product",
            handle: "brand-new-product",
            variants: [
              shopify_variant_payload(id: 202, title: "Brand New Variant", position: 1)
            ]
          )
        ])
      ]
    }) do |service|
      service.sync_all_products
    end

    assert_equal 2, result[:products_updated]
    assert_equal 2, result[:variants_updated]
    assert_equal 0, result[:products_archived]
    assert_equal 0, result[:variants_archived]
    assert_empty result[:failures]
    assert result[:full_reconciliation_completed]

    assert_equal "Updated Product Title", product.reload.title
    assert_equal "Updated Variant Title", variant.reload.title
    assert_nil product.removed_from_source_at
    assert_nil variant.removed_from_source_at
    assert_not_nil product.last_seen_in_source_at
    assert_not_nil variant.last_seen_in_source_at

    new_product = store.products.find_by!(external_id: "102")
    new_variant = new_product.product_variants.find_by!(external_variant_id: "202")
    assert_equal "Brand New Product", new_product.title
    assert_equal "Brand New Variant", new_variant.title

    assert_equal "Historic Product Title", order_item.reload.title
    assert_equal "Historic Variant Title", order_item.reload.variant_title
  end

  test "full sync archives removed variants without destroying local mappings, bundles, or order item references" do
    store = create_store!
    product = create_product!(store: store, external_id: "101")
    kept_variant = create_variant!(product: product, external_variant_id: "201", title: "Keep Me", position: 1)
    removed_variant = create_variant!(product: product, external_variant_id: "202", title: "Remove Me", position: 2)
    bundle = removed_variant.bundle
    mapping = create_variant_mapping!(product_variant: removed_variant, bundle: bundle)
    order_item = create_order_item!(store: store, product: product, variant: removed_variant)

    result = with_fake_shopify_client(store, {
      "GetProductsForSync" => [
        products_response([
          shopify_product_payload(
            id: 101,
            title: product.title,
            handle: product.handle,
            variants: [
              shopify_variant_payload(id: 201, title: kept_variant.title, position: 1)
            ]
          )
        ])
      ]
    }) do |service|
      service.sync_all_products
    end

    assert_equal 1, result[:variants_archived]
    assert_equal 0, result[:products_archived]
    assert removed_variant.reload.removed_from_source?
    assert kept_variant.reload.present_in_source?
    assert_equal 2, product.reload.product_variants.count
    assert_equal bundle.id, removed_variant.bundle.reload.id
    assert_equal mapping.id, mapping.reload.id
    assert_equal removed_variant.id, mapping.product_variant_id
    assert_equal removed_variant.id, order_item.reload.product_variant_id
  end

  test "full sync archives removed products and child variants without destroying local records" do
    store = create_store!
    product = create_product!(store: store, external_id: "101")
    variant = create_variant!(product: product, external_variant_id: "201", position: 1)
    bundle = variant.bundle
    mapping = create_variant_mapping!(product_variant: variant, bundle: bundle)
    order_item = create_order_item!(store: store, product: product, variant: variant)

    result = with_fake_shopify_client(store, {
      "GetProductsForSync" => [
        products_response([])
      ]
    }) do |service|
      service.sync_all_products
    end

    assert_equal 1, result[:products_archived]
    assert_equal 1, result[:variants_archived]
    assert product.reload.removed_from_source?
    assert variant.reload.removed_from_source?
    assert_equal bundle.id, variant.bundle.reload.id
    assert_equal mapping.id, mapping.reload.id
    assert_equal variant.id, order_item.reload.product_variant_id
  end

  test "full sync reactivates archived products and variants in place" do
    archived_at = 2.days.ago
    store = create_store!
    product = create_product!(store: store, external_id: "101", removed_from_source_at: archived_at)
    variant = create_variant!(product: product, external_variant_id: "201", position: 1, removed_from_source_at: archived_at)

    result = with_fake_shopify_client(store, {
      "GetProductsForSync" => [
        products_response([
          shopify_product_payload(
            id: 101,
            title: "Reactivated Product",
            handle: "reactivated-product",
            variants: [
              shopify_variant_payload(id: 201, title: "Reactivated Variant", position: 1)
            ]
          )
        ])
      ]
    }) do |service|
      service.sync_all_products
    end

    assert_equal 1, result[:products_reactivated]
    assert_equal 1, result[:variants_reactivated]
    assert_equal product.id, product.reload.id
    assert_equal variant.id, variant.reload.id
    assert_nil product.removed_from_source_at
    assert_nil variant.removed_from_source_at
    assert_equal "Reactivated Product", product.title
    assert_equal "Reactivated Variant", variant.title
  end

  test "single product sync updates only the selected product and archives only its missing variants" do
    store = create_store!
    target_product = create_product!(store: store, external_id: "101", title: "Target Product")
    kept_variant = create_variant!(product: target_product, external_variant_id: "201", title: "Keep Variant", position: 1)
    removed_variant = create_variant!(product: target_product, external_variant_id: "202", title: "Archive Variant", position: 2)
    untouched_product = create_product!(store: store, external_id: "102", title: "Untouched Product")
    untouched_variant = create_variant!(product: untouched_product, external_variant_id: "301", title: "Untouched Variant", position: 1)

    result = with_fake_shopify_client(store, {
      "GetProductByID" => [
        single_product_response(
          shopify_product_payload(
            id: 101,
            title: "Target Product Updated",
            handle: "target-product-updated",
            variants: [
              shopify_variant_payload(id: 201, title: "Keep Variant Updated", position: 1)
            ]
          )
        )
      ]
    }) do |service|
      service.sync_single_product("101")
    end

    assert_equal 1, result[:products_updated]
    assert_equal 1, result[:variants_archived]
    assert result[:full_reconciliation_completed]
    assert_equal "Target Product Updated", target_product.reload.title
    assert_equal "Keep Variant Updated", kept_variant.reload.title
    assert removed_variant.reload.removed_from_source?
    assert_equal "Untouched Product", untouched_product.reload.title
    assert untouched_product.present_in_source?
    assert untouched_variant.reload.present_in_source?
    assert_nil untouched_product.last_seen_in_source_at
  end

  test "single product sync archives the local product when Shopify reports it missing" do
    store = create_store!
    product = create_product!(store: store, external_id: "101")
    variant = create_variant!(product: product, external_variant_id: "201", position: 1)

    result = with_fake_shopify_client(store, {
      "GetProductByID" => [
        single_product_response(nil)
      ]
    }) do |service|
      service.sync_single_product("101")
    end

    assert result[:product_missing]
    assert result[:full_reconciliation_completed]
    assert_equal 1, result[:products_archived]
    assert_equal 1, result[:variants_archived]
    assert product.reload.removed_from_source?
    assert variant.reload.removed_from_source?
  end

  test "full sync skips archival when variant pagination is incomplete" do
    store = create_store!
    partial_product = create_product!(store: store, external_id: "101")
    kept_variant = create_variant!(product: partial_product, external_variant_id: "201", title: "Seen Variant", position: 1)
    extra_variant = create_variant!(product: partial_product, external_variant_id: "202", title: "Missing Variant", position: 2)
    untouched_product = create_product!(store: store, external_id: "102")

    result = with_fake_shopify_client(store, {
      "GetProductsForSync" => [
        products_response([
          shopify_product_payload(
            id: 101,
            title: partial_product.title,
            handle: partial_product.handle,
            variants: [
              shopify_variant_payload(id: 201, title: kept_variant.title, position: 1)
            ],
            variants_has_next_page: true,
            variants_end_cursor: "cursor-1"
          )
        ])
      ],
      "GetProductVariantsPage" => [
        { "data" => { "product" => nil } }
      ]
    }) do |service|
      service.sync_all_products
    end

    assert_not result[:full_reconciliation_completed]
    assert_equal 0, result[:products_archived]
    assert_equal 0, result[:variants_archived]
    assert extra_variant.reload.present_in_source?
    assert untouched_product.reload.present_in_source?
    assert_includes result[:failures].join(" "), "variant pagination was incomplete"
  end

  test "single product sync keeps existing variants active when variant pagination is incomplete" do
    store = create_store!
    product = create_product!(store: store, external_id: "101")
    kept_variant = create_variant!(product: product, external_variant_id: "201", title: "Seen Variant", position: 1)
    extra_variant = create_variant!(product: product, external_variant_id: "202", title: "Missing Variant", position: 2)

    result = with_fake_shopify_client(store, {
      "GetProductByID" => [
        single_product_response(
          shopify_product_payload(
            id: 101,
            title: product.title,
            handle: product.handle,
            variants: [
              shopify_variant_payload(id: 201, title: kept_variant.title, position: 1)
            ],
            variants_has_next_page: true,
            variants_end_cursor: "cursor-1"
          )
        )
      ],
      "GetProductVariantsPage" => [
        { "data" => { "product" => nil } }
      ]
    }) do |service|
      service.sync_single_product("101")
    end

    assert_not result[:full_reconciliation_completed]
    assert extra_variant.reload.present_in_source?
    assert_includes result[:failures].join(" "), "missing variants were not archived"
  end

  test "full sync paginates variants beyond the first 250 before reconciling missing variants" do
    store = create_store!
    product = create_product!(store: store, external_id: "101")
    archived_candidate = create_variant!(product: product, external_variant_id: "9999", title: "Archive Me", position: 252)

    first_page_variants = (1..250).map do |index|
      shopify_variant_payload(id: index, title: "Variant #{index}", position: index)
    end
    second_page_variants = [
      shopify_variant_payload(id: 251, title: "Variant 251", position: 251)
    ]

    result = with_fake_shopify_client(store, {
      "GetProductsForSync" => [
        products_response([
          shopify_product_payload(
            id: 101,
            title: "Mega Product",
            handle: "mega-product",
            variants: first_page_variants,
            variants_has_next_page: true,
            variants_end_cursor: "cursor-250"
          )
        ])
      ],
      "GetProductVariantsPage" => [
        variants_page_response(second_page_variants)
      ]
    }) do |service|
      service.sync_all_products
    end

    assert result[:full_reconciliation_completed]
    assert_empty result[:failures]
    assert_equal 1, result[:products_updated]
    assert_equal 251, result[:variants_updated]
    assert_equal 1, result[:variants_archived]
    assert_equal 251, product.reload.product_variants.present_in_source.count
    assert product.product_variants.find_by!(external_variant_id: "251").present_in_source?
    assert archived_candidate.reload.removed_from_source?
  end

  private

  def with_fake_shopify_client(store, operation_responses)
    client = FakeGraphqlAdminClient.new(operation_responses)
    service = ShopifyProductSyncService.new(store)
    service.instance_variable_set(:@graphql_client, client)
    yield service, client
  end

  def create_store!
    organization = Organization.create!(name: unique_name("Org"))
    user = User.create!(email: unique_email, organization: organization)

    Store.create!(
      organization: organization,
      created_by_user: user,
      uid: unique_name("store").parameterize,
      platform: "shopify",
      name: unique_name("Test Store"),
      shopify_domain: "#{SecureRandom.hex(6)}.myshopify.com",
      shopify_token: "test_token",
      access_scopes: "read_products"
    )
  end

  def create_product!(store:, external_id:, title: "Test Product", handle: nil, removed_from_source_at: nil)
    Product.create!(
      store: store,
      external_id: external_id.to_s,
      title: title,
      handle: handle || "#{title.parameterize}-#{external_id}",
      status: "active",
      vendor: "Framefox",
      product_type: "Print",
      removed_from_source_at: removed_from_source_at
    )
  end

  def create_variant!(product:, external_variant_id:, title: "Test Variant", position:, removed_from_source_at: nil)
    ProductVariant.create!(
      product: product,
      external_variant_id: external_variant_id.to_s,
      title: title,
      sku: "SKU-#{external_variant_id}",
      position: position,
      price: 99.0,
      available_for_sale: true,
      requires_shipping: true,
      selected_options: [ { "name" => "Size", "value" => "A4" } ],
      removed_from_source_at: removed_from_source_at
    )
  end

  def create_variant_mapping!(product_variant:, bundle:)
    VariantMapping.create!(
      product_variant: product_variant,
      bundle: bundle,
      slot_position: 1,
      country_code: "NZ",
      frame_sku_id: 1,
      frame_sku_code: "FRAME-1",
      frame_sku_title: "Black Frame",
      frame_sku_description: "Test frame",
      frame_sku_cost_cents: 1200,
      frame_sku_long: 297,
      frame_sku_short: 210,
      frame_sku_unit: "mm",
      width: 210,
      height: 297,
      unit: "mm"
    )
  end

  def create_order_item!(store:, product:, variant:, title: product.title, variant_title: variant.title)
    order = Order.create!(
      store: store,
      organization: store.organization,
      external_id: unique_name("order"),
      currency: "NZD",
      subtotal_price_cents: 0,
      total_discounts_cents: 0,
      total_shipping_cents: 0,
      total_tax_cents: 0,
      total_price_cents: 0,
      production_subtotal_cents: 0,
      production_shipping_cents: 0,
      production_total_cents: 0
    )

    OrderItem.create!(
      order: order,
      product_variant: variant,
      external_line_id: unique_name("line"),
      external_product_id: product.external_id,
      external_variant_id: variant.external_variant_id,
      title: title,
      sku: variant.sku,
      variant_title: variant_title,
      quantity: 1,
      taxes_included: false,
      requires_shipping: true,
      price_cents: 1000,
      total_cents: 1000,
      discount_amount_cents: 0,
      tax_amount_cents: 0,
      production_cost_cents: 500
    )
  end

  def products_response(products)
    {
      "data" => {
        "products" => {
          "edges" => products.map { |product| { "node" => product } },
          "pageInfo" => {
            "hasNextPage" => false,
            "endCursor" => nil
          }
        }
      }
    }
  end

  def single_product_response(product)
    {
      "data" => {
        "product" => product
      }
    }
  end

  def variants_page_response(variants, has_next_page: false, end_cursor: nil)
    {
      "data" => {
        "product" => {
          "variants" => {
            "edges" => variants.map { |variant| { "node" => variant } },
            "pageInfo" => {
              "hasNextPage" => has_next_page,
              "endCursor" => end_cursor
            }
          }
        }
      }
    }
  end

  def shopify_product_payload(id:, title:, handle:, variants:, status: "ACTIVE", variants_has_next_page: false, variants_end_cursor: nil)
    {
      "id" => shopify_gid("Product", id),
      "title" => title,
      "handle" => handle,
      "productType" => "Print",
      "vendor" => "Framefox",
      "tags" => [ "art" ],
      "status" => status,
      "publishedAt" => "2026-03-01T00:00:00Z",
      "createdAt" => "2026-03-01T00:00:00Z",
      "updatedAt" => "2026-03-02T00:00:00Z",
      "options" => [
        {
          "id" => shopify_gid("ProductOption", id),
          "name" => "Size",
          "position" => 1,
          "values" => [ "A4" ]
        }
      ],
      "featuredMedia" => {
        "image" => {
          "url" => "https://example.com/products/#{id}.jpg",
          "altText" => title,
          "width" => 1200,
          "height" => 1200
        }
      },
      "variants" => {
        "edges" => variants.map { |variant| { "node" => variant } },
        "pageInfo" => {
          "hasNextPage" => variants_has_next_page,
          "endCursor" => variants_end_cursor
        }
      }
    }
  end

  def shopify_variant_payload(id:, title:, position:, price: "99.0")
    {
      "id" => shopify_gid("ProductVariant", id),
      "title" => title,
      "price" => price,
      "compareAtPrice" => nil,
      "sku" => "SKU-#{id}",
      "barcode" => "BAR-#{id}",
      "position" => position,
      "availableForSale" => true,
      "createdAt" => "2026-03-01T00:00:00Z",
      "updatedAt" => "2026-03-02T00:00:00Z",
      "inventoryItem" => {
        "id" => shopify_gid("InventoryItem", id),
        "requiresShipping" => true,
        "measurement" => {
          "weight" => {
            "value" => 1.25,
            "unit" => "KILOGRAMS"
          }
        }
      },
      "selectedOptions" => [
        {
          "name" => "Size",
          "value" => "A4"
        }
      ],
      "image" => {
        "url" => "https://example.com/variants/#{id}.jpg",
        "altText" => title,
        "width" => 1200,
        "height" => 1200
      }
    }
  end

  def shopify_gid(resource, id)
    "gid://shopify/#{resource}/#{id}"
  end

  def unique_email
    "sync-test-#{SecureRandom.hex(6)}@example.com"
  end

  def unique_name(prefix)
    "#{prefix}-#{SecureRandom.hex(6)}"
  end
end
