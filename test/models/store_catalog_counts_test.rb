require "test_helper"

class StoreCatalogCountsTest < ActiveSupport::TestCase
  test "catalog counts stay on this store and skip removed rows unless asked" do
    store = create_store!("catalog")
    other_store = create_store!("other")
    visible = create_product!(store, "visible")
    removed_product = create_product!(store, "removed", removed_from_source_at: Time.current)
    create_variant!(visible, "active", fulfilment_active: true)
    create_variant!(visible, "inactive", fulfilment_active: false)
    create_variant!(visible, "archived-variant", removed_from_source_at: Time.current)
    create_variant!(removed_product, "on-removed-product", fulfilment_active: true)
    create_variant!(create_product!(other_store, "elsewhere"), "other-variant", fulfilment_active: true)

    counts = store.catalog_counts(include_archived: false)

    assert_equal 1, counts[:products_count]
    assert_equal 3, counts[:variants_count]
    assert_equal 1, counts[:archived_products_count]
    assert_equal 1, counts[:archived_variants_count]

    with_archived = store.catalog_counts(include_archived: true)
    assert_equal 2, with_archived[:products_count]
    assert_equal 4, with_archived[:variants_count]
  end

  test "preloaded variant counts match per-product queries without further lookups" do
    store = create_store!("preload")
    product = create_product!(store, "framed")
    empty = create_product!(store, "empty")
    create_variant!(product, "active", fulfilment_active: true)
    create_variant!(product, "inactive", fulfilment_active: false)
    create_variant!(product, "removed", removed_from_source_at: Time.current)

    loaded = Product.preload_variant_counts(store.products.order(:id))

    assert_equal [2, 1], [loaded.first.total_variants_count, loaded.first.active_variants_count]
    assert_equal [0, 0], [loaded.second.total_variants_count, loaded.second.active_variants_count]
    assert_equal empty.id, loaded.second.id

    queries = capture_sql do
      loaded.each { |record| record.active_variants_count + record.total_variants_count }
    end
    assert_empty queries
  end

  private

  def create_store!(label)
    organization = Organization.create!(name: "Catalog #{label} #{SecureRandom.hex(4)}")
    user = User.create!(email: "#{label}-#{SecureRandom.hex(4)}@example.com", organization: organization)
    Store.create!(
      organization: organization,
      created_by_user: user,
      name: "Catalog #{label}",
      platform: "shopify",
      shopify_domain: "#{label}-#{SecureRandom.hex(4)}.myshopify.com",
      shopify_token: "test-token",
      access_scopes: "read_products",
      uid: "#{label}-#{SecureRandom.hex(4)}"
    )
  end

  def create_product!(store, external_id, removed_from_source_at: nil)
    Product.create!(
      store: store,
      external_id: external_id,
      title: external_id,
      handle: "#{external_id}-#{SecureRandom.hex(2)}",
      status: "active",
      removed_from_source_at: removed_from_source_at
    )
  end

  def create_variant!(product, external_variant_id, fulfilment_active: false, removed_from_source_at: nil)
    ProductVariant.create!(
      product: product,
      external_variant_id: external_variant_id,
      title: external_variant_id,
      position: product.product_variants.count + 1,
      price: 10,
      fulfilment_active: fulfilment_active,
      removed_from_source_at: removed_from_source_at
    )
  end

  def capture_sql
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] unless payload[:name] == "SCHEMA"
    end
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }
    queries
  end
end
