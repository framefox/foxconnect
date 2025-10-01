# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2025_10_01_083457) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "external_line_id"
    t.string "external_product_id"
    t.string "external_variant_id"
    t.string "title"
    t.string "sku"
    t.string "variant_title"
    t.integer "quantity", default: 1, null: false
    t.decimal "price", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "discount_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "tax_amount", precision: 12, scale: 2, default: "0.0", null: false
    t.boolean "taxes_included", default: false
    t.boolean "requires_shipping", default: true
    t.bigint "product_variant_id"
    t.bigint "variant_mapping_id"
    t.json "raw_payload", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_order_items_on_deleted_at"
    t.index ["external_product_id"], name: "index_order_items_on_external_product_id"
    t.index ["external_variant_id"], name: "index_order_items_on_external_variant_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
    t.index ["variant_mapping_id"], name: "index_order_items_on_variant_mapping_id"
    t.check_constraint "discount_amount >= 0::numeric", name: "order_items_disc_nonneg"
    t.check_constraint "price >= 0::numeric", name: "order_items_price_nonneg"
    t.check_constraint "quantity > 0", name: "order_items_qty_positive"
    t.check_constraint "tax_amount >= 0::numeric", name: "order_items_tax_nonneg"
    t.check_constraint "total >= 0::numeric", name: "order_items_total_nonneg"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.string "external_id", null: false
    t.string "external_number"
    t.string "name"
    t.string "customer_email"
    t.string "customer_phone"
    t.string "currency", null: false
    t.decimal "subtotal_price", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_discounts", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_shipping", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_tax", precision: 12, scale: 2, default: "0.0", null: false
    t.decimal "total_price", precision: 12, scale: 2, default: "0.0", null: false
    t.string "financial_status"
    t.string "fulfillment_status"
    t.datetime "processed_at"
    t.datetime "cancelled_at"
    t.datetime "closed_at"
    t.string "cancel_reason"
    t.json "tags", default: []
    t.text "note"
    t.json "raw_payload", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "aasm_state", default: "draft", null: false
    t.string "shopify_draft_order_id"
    t.string "shopify_remote_order_id"
    t.index ["aasm_state"], name: "index_orders_on_aasm_state"
    t.index ["shopify_draft_order_id"], name: "index_orders_on_shopify_draft_order_id"
    t.index ["shopify_remote_order_id"], name: "index_orders_on_shopify_remote_order_id"
    t.index ["store_id", "external_id"], name: "index_orders_on_store_id_and_external_id", unique: true
    t.index ["store_id", "processed_at"], name: "index_orders_on_store_id_and_processed_at"
    t.index ["store_id"], name: "index_orders_on_store_id"
    t.check_constraint "char_length(currency::text) = 3", name: "orders_currency_len_3"
    t.check_constraint "subtotal_price >= 0::numeric", name: "orders_subtotal_nonneg"
    t.check_constraint "total_discounts >= 0::numeric", name: "orders_discounts_nonneg"
    t.check_constraint "total_price >= 0::numeric", name: "orders_total_nonneg"
    t.check_constraint "total_shipping >= 0::numeric", name: "orders_shipping_nonneg"
    t.check_constraint "total_tax >= 0::numeric", name: "orders_tax_nonneg"
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "external_variant_id", null: false
    t.string "title", null: false
    t.string "sku"
    t.string "barcode"
    t.integer "position", default: 1
    t.decimal "price", precision: 10, scale: 2
    t.decimal "compare_at_price", precision: 10, scale: 2
    t.boolean "available_for_sale", default: true
    t.decimal "weight", precision: 8, scale: 3
    t.string "weight_unit", default: "kg"
    t.boolean "requires_shipping", default: true
    t.json "selected_options", default: []
    t.string "image_url"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "fulfilment_active", default: false, null: false
    t.index ["available_for_sale"], name: "index_product_variants_on_available_for_sale"
    t.index ["barcode"], name: "index_product_variants_on_barcode"
    t.index ["fulfilment_active"], name: "index_product_variants_on_fulfilment_active"
    t.index ["position"], name: "index_product_variants_on_position"
    t.index ["product_id", "external_variant_id"], name: "index_product_variants_on_product_id_and_external_variant_id", unique: true
    t.index ["product_id", "position"], name: "index_product_variants_on_product_id_and_position"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "external_id", null: false
    t.string "title", null: false
    t.string "handle", null: false
    t.string "product_type"
    t.string "vendor"
    t.json "tags", default: []
    t.json "options", default: []
    t.json "images", default: []
    t.string "featured_image_url"
    t.string "status", default: "draft"
    t.datetime "published_at"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "store_id", null: false
    t.boolean "fulfilment_active", default: false, null: false
    t.index ["fulfilment_active"], name: "index_products_on_fulfilment_active"
    t.index ["handle"], name: "index_products_on_handle"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["status"], name: "index_products_on_status"
    t.index ["store_id", "external_id"], name: "index_products_on_store_id_and_external_id", unique: true
    t.index ["store_id"], name: "index_products_on_store_id"
    t.index ["title"], name: "index_products_on_title"
    t.index ["vendor"], name: "index_products_on_vendor"
  end

  create_table "shipping_addresses", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "company"
    t.string "name"
    t.string "phone"
    t.string "address1"
    t.string "address2"
    t.string "city"
    t.string "province"
    t.string "province_code"
    t.string "postal_code"
    t.string "country"
    t.string "country_code"
    t.float "latitude"
    t.float "longitude"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_shipping_addresses_on_order_id"
    t.check_constraint "char_length(country_code::text) = ANY (ARRAY[0, 2])", name: "ship_addr_country_code_len"
    t.check_constraint "char_length(province_code::text) = ANY (ARRAY[0, 2, 3])", name: "ship_addr_province_code_len"
  end

  create_table "stores", force: :cascade do |t|
    t.string "name", null: false
    t.string "platform", default: "shopify", null: false
    t.string "shopify_domain"
    t.string "shopify_token"
    t.string "access_scopes"
    t.json "settings", default: {}
    t.boolean "active", default: true
    t.datetime "last_sync_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "wix_site_id"
    t.string "wix_token"
    t.string "squarespace_domain"
    t.string "squarespace_token"
    t.index ["platform", "active"], name: "index_stores_on_platform_and_active"
    t.index ["platform"], name: "index_stores_on_platform"
    t.index ["shopify_domain"], name: "index_stores_on_shopify_domain", unique: true, where: "(shopify_domain IS NOT NULL)"
    t.index ["squarespace_domain"], name: "index_stores_on_squarespace_domain", unique: true, where: "(squarespace_domain IS NOT NULL)"
    t.index ["wix_site_id"], name: "index_stores_on_wix_site_id", unique: true, where: "(wix_site_id IS NOT NULL)"
  end

  create_table "variant_mappings", force: :cascade do |t|
    t.bigint "product_variant_id", null: false
    t.integer "image_id"
    t.string "image_key"
    t.integer "frame_sku_id"
    t.string "frame_sku_code"
    t.string "frame_sku_title"
    t.integer "cx"
    t.integer "cy"
    t.integer "cw"
    t.integer "ch"
    t.string "preview_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cloudinary_id"
    t.integer "image_width"
    t.integer "image_height"
    t.integer "frame_sku_cost_cents", null: false
    t.text "frame_sku_description"
    t.string "image_filename"
    t.integer "frame_sku_long"
    t.integer "frame_sku_short"
    t.string "frame_sku_unit"
    t.index ["frame_sku_code"], name: "index_variant_mappings_on_frame_sku_code"
    t.index ["frame_sku_cost_cents"], name: "index_variant_mappings_on_frame_sku_cost_cents"
    t.index ["frame_sku_id"], name: "index_variant_mappings_on_frame_sku_id"
    t.index ["image_id"], name: "index_variant_mappings_on_image_id"
    t.index ["product_variant_id"], name: "index_variant_mappings_on_product_variant_id"
  end

  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "variant_mappings"
  add_foreign_key "orders", "stores"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "stores"
  add_foreign_key "shipping_addresses", "orders"
  add_foreign_key "variant_mappings", "product_variants"
end
