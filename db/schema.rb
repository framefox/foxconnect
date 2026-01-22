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

ActiveRecord::Schema[8.0].define(version: 2026_01_22_003404) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_stat_statements"

  create_table "bulk_mapping_requests", force: :cascade do |t|
    t.bigint "store_id", null: false
    t.string "variant_title", null: false
    t.string "frame_sku_title", null: false
    t.integer "total_count", default: 0, null: false
    t.integer "created_count", default: 0, null: false
    t.integer "skipped_count", default: 0, null: false
    t.string "status", default: "pending", null: false
    t.text "error_messages"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_bulk_mapping_requests_on_status"
    t.index ["store_id"], name: "index_bulk_mapping_requests_on_store_id"
  end

  create_table "bundles", force: :cascade do |t|
    t.bigint "product_variant_id", null: false
    t.integer "slot_count", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_variant_id"], name: "index_bundles_on_product_variant_id", unique: true
  end

  create_table "companies", force: :cascade do |t|
    t.string "company_name", null: false
    t.string "shopify_company_id", null: false
    t.string "shopify_company_location_id", null: false
    t.string "shopify_company_contact_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shopify_company_id"], name: "index_companies_on_shopify_company_id", unique: true
  end

  create_table "custom_print_sizes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.decimal "long", precision: 6, scale: 2, null: false
    t.decimal "short", precision: 6, scale: 2, null: false
    t.string "unit", null: false
    t.integer "frame_sku_size_id", null: false
    t.string "frame_sku_size_description", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_custom_print_sizes_on_user_id"
  end

  create_table "fulfillment_line_items", force: :cascade do |t|
    t.bigint "fulfillment_id", null: false
    t.bigint "order_item_id", null: false
    t.integer "quantity", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fulfillment_id", "order_item_id"], name: "index_fulfillment_line_items_on_fulfillment_and_order_item", unique: true
    t.index ["fulfillment_id"], name: "index_fulfillment_line_items_on_fulfillment_id"
    t.index ["order_item_id"], name: "index_fulfillment_line_items_on_order_item_id"
  end

  create_table "fulfillments", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "shopify_fulfillment_id"
    t.string "status", null: false
    t.string "tracking_company"
    t.string "tracking_number"
    t.string "tracking_url"
    t.string "location_name"
    t.string "shopify_location_id"
    t.string "shipment_status"
    t.datetime "fulfilled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_fulfillments_on_order_id"
    t.index ["shopify_fulfillment_id"], name: "index_fulfillments_on_shopify_fulfillment_id", unique: true
  end

  create_table "images", force: :cascade do |t|
    t.integer "external_image_id", null: false
    t.string "image_key", null: false
    t.string "cloudinary_id"
    t.integer "image_width"
    t.integer "image_height"
    t.string "image_filename"
    t.integer "cx", null: false
    t.integer "cy", null: false
    t.integer "cw", null: false
    t.integer "ch", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_image_id"], name: "index_images_on_external_image_id"
  end

  create_table "order_activities", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "activity_type", null: false
    t.string "title", null: false
    t.text "description"
    t.json "metadata", default: {}
    t.string "actor_type"
    t.integer "actor_id"
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["activity_type"], name: "index_order_activities_on_activity_type"
    t.index ["actor_type", "actor_id"], name: "index_order_activities_on_actor_type_and_actor_id"
    t.index ["order_id", "occurred_at"], name: "index_order_activities_on_order_id_and_occurred_at"
    t.index ["order_id"], name: "index_order_activities_on_order_id"
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.string "external_line_id"
    t.string "external_product_id"
    t.string "external_variant_id"
    t.string "title"
    t.string "sku"
    t.string "variant_title"
    t.integer "quantity", default: 1, null: false
    t.boolean "taxes_included", default: false
    t.boolean "requires_shipping", default: true
    t.bigint "product_variant_id"
    t.bigint "variant_mapping_id"
    t.json "raw_payload", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.string "shopify_remote_line_item_id"
    t.integer "price_cents", default: 0, null: false
    t.integer "total_cents", default: 0, null: false
    t.integer "discount_amount_cents", default: 0, null: false
    t.integer "tax_amount_cents", default: 0, null: false
    t.integer "production_cost_cents", default: 0, null: false
    t.boolean "is_custom", default: false, null: false
    t.integer "bundle_slot_count", default: 1, null: false
    t.index ["deleted_at"], name: "index_order_items_on_deleted_at"
    t.index ["external_product_id"], name: "index_order_items_on_external_product_id"
    t.index ["external_variant_id"], name: "index_order_items_on_external_variant_id"
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_variant_id"], name: "index_order_items_on_product_variant_id"
    t.index ["shopify_remote_line_item_id"], name: "index_order_items_on_shopify_remote_line_item_id"
    t.index ["variant_mapping_id"], name: "index_order_items_on_variant_mapping_id"
    t.check_constraint "discount_amount_cents >= 0", name: "order_items_disc_nonneg"
    t.check_constraint "price_cents >= 0", name: "order_items_price_nonneg"
    t.check_constraint "production_cost_cents >= 0", name: "order_items_production_cost_nonneg"
    t.check_constraint "quantity > 0", name: "order_items_qty_positive"
    t.check_constraint "tax_amount_cents >= 0", name: "order_items_tax_nonneg"
    t.check_constraint "total_cents >= 0", name: "order_items_total_nonneg"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "store_id"
    t.string "external_id", null: false
    t.string "external_number"
    t.string "name"
    t.string "customer_phone"
    t.string "currency", null: false
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
    t.string "shopify_remote_draft_order_id"
    t.string "shopify_remote_order_id"
    t.string "shopify_remote_order_name"
    t.date "target_dispatch_date"
    t.datetime "in_production_at"
    t.integer "subtotal_price_cents", default: 0, null: false
    t.integer "total_discounts_cents", default: 0, null: false
    t.integer "total_shipping_cents", default: 0, null: false
    t.integer "total_tax_cents", default: 0, null: false
    t.integer "total_price_cents", default: 0, null: false
    t.integer "production_subtotal_cents", default: 0, null: false
    t.integer "production_shipping_cents", default: 0, null: false
    t.integer "production_total_cents", default: 0, null: false
    t.string "country_code", limit: 2
    t.datetime "production_paid_at"
    t.string "uid", null: false
    t.bigint "user_id"
    t.string "fulfillment_currency", limit: 3
    t.index ["aasm_state"], name: "index_orders_on_aasm_state"
    t.index ["country_code"], name: "index_orders_on_country_code"
    t.index ["external_id"], name: "index_orders_on_external_id_for_manual_orders", unique: true, where: "(store_id IS NULL)"
    t.index ["shopify_remote_draft_order_id"], name: "index_orders_on_shopify_remote_draft_order_id"
    t.index ["shopify_remote_order_id"], name: "index_orders_on_shopify_remote_order_id"
    t.index ["store_id", "external_id"], name: "index_orders_on_store_id_and_external_id_not_null", unique: true, where: "(store_id IS NOT NULL)"
    t.index ["store_id", "processed_at"], name: "index_orders_on_store_id_and_processed_at"
    t.index ["store_id"], name: "index_orders_on_store_id"
    t.index ["uid"], name: "index_orders_on_uid", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
    t.check_constraint "char_length(currency::text) = 3", name: "orders_currency_len_3"
    t.check_constraint "char_length(fulfillment_currency::text) = 3", name: "orders_fulfillment_currency_len_3"
    t.check_constraint "production_shipping_cents >= 0", name: "orders_production_shipping_nonneg"
    t.check_constraint "production_subtotal_cents >= 0", name: "orders_production_subtotal_nonneg"
    t.check_constraint "production_total_cents >= 0", name: "orders_production_total_nonneg"
    t.check_constraint "subtotal_price_cents >= 0", name: "orders_subtotal_nonneg"
    t.check_constraint "total_discounts_cents >= 0", name: "orders_discounts_nonneg"
    t.check_constraint "total_price_cents >= 0", name: "orders_total_nonneg"
    t.check_constraint "total_shipping_cents >= 0", name: "orders_shipping_nonneg"
    t.check_constraint "total_tax_cents >= 0", name: "orders_tax_nonneg"
  end

  create_table "organizations", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_organizations_on_uid", unique: true
  end

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "external_variant_id", null: false
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
    t.string "external_id", null: false
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
    t.boolean "bundles_enabled", default: false, null: false
    t.index ["fulfilment_active"], name: "index_products_on_fulfilment_active"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["status"], name: "index_products_on_status"
    t.index ["store_id", "external_id"], name: "index_products_on_store_id_and_external_id", unique: true
    t.index ["store_id", "handle"], name: "index_products_on_store_id_and_handle_unique", unique: true
    t.index ["store_id"], name: "index_products_on_store_id"
    t.index ["title"], name: "index_products_on_title"
    t.index ["vendor"], name: "index_products_on_vendor"
  end

  create_table "saved_items", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.integer "frame_sku_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "custom_print_size_id"
    t.index ["custom_print_size_id"], name: "index_saved_items_on_custom_print_size_id"
    t.index ["user_id", "frame_sku_id"], name: "index_saved_items_on_user_id_and_frame_sku_id", unique: true
    t.index ["user_id"], name: "index_saved_items_on_user_id"
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

  create_table "shopify_customers", force: :cascade do |t|
    t.bigint "external_shopify_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "company_id"
    t.bigint "user_id", null: false
    t.string "country_code", limit: 2, null: false
    t.index ["company_id"], name: "index_shopify_customers_on_company_id"
    t.index ["external_shopify_id"], name: "index_shopify_customers_on_external_shopify_id", unique: true
    t.index ["user_id", "country_code"], name: "index_shopify_customers_on_user_id_and_country_code", unique: true
    t.index ["user_id"], name: "index_shopify_customers_on_user_id"
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
    t.bigint "created_by_user_id", null: false
    t.boolean "fulfill_new_products", default: false
    t.datetime "products_last_updated_at"
    t.string "uid", null: false
    t.boolean "ai_mapping_enabled", default: false
    t.text "ai_mapping_prompt"
    t.string "mockup_bg_colour", default: "f4f4f4"
    t.string "squarespace_refresh_token"
    t.datetime "squarespace_token_expires_at"
    t.datetime "squarespace_refresh_token_expires_at"
    t.boolean "order_import_paused", default: false, null: false
    t.boolean "needs_reauthentication", default: false, null: false
    t.datetime "reauthentication_flagged_at"
    t.string "shopify_fulfillment_service_id"
    t.string "shopify_fulfillment_location_id"
    t.bigint "organization_id"
    t.index ["created_by_user_id"], name: "index_stores_on_created_by_user_id"
    t.index ["needs_reauthentication"], name: "index_stores_on_needs_reauthentication"
    t.index ["organization_id"], name: "index_stores_on_organization_id"
    t.index ["platform", "active"], name: "index_stores_on_platform_and_active"
    t.index ["platform"], name: "index_stores_on_platform"
    t.index ["products_last_updated_at"], name: "index_stores_on_products_last_updated_at"
    t.index ["shopify_domain"], name: "index_stores_on_shopify_domain", unique: true, where: "(shopify_domain IS NOT NULL)"
    t.index ["shopify_fulfillment_service_id"], name: "index_stores_on_shopify_fulfillment_service_id", unique: true, where: "(shopify_fulfillment_service_id IS NOT NULL)"
    t.index ["squarespace_domain"], name: "index_stores_on_squarespace_domain", unique: true, where: "(squarespace_domain IS NOT NULL)"
    t.index ["uid"], name: "index_stores_on_uid", unique: true
    t.index ["wix_site_id"], name: "index_stores_on_wix_site_id", unique: true, where: "(wix_site_id IS NOT NULL)"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "first_name"
    t.string "last_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.boolean "admin", default: false, null: false
    t.string "country"
    t.bigint "organization_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["organization_id"], name: "index_users_on_organization_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "variant_mappings", force: :cascade do |t|
    t.bigint "product_variant_id"
    t.integer "frame_sku_id"
    t.string "frame_sku_code"
    t.string "frame_sku_title"
    t.string "preview_url"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "frame_sku_cost_cents", null: false
    t.text "frame_sku_description"
    t.integer "frame_sku_long"
    t.integer "frame_sku_short"
    t.string "frame_sku_unit"
    t.boolean "is_default", default: false, null: false
    t.string "country_code", limit: 2, default: "NZ", null: false
    t.decimal "width", precision: 6, scale: 2
    t.decimal "height", precision: 6, scale: 2
    t.string "unit"
    t.string "colour"
    t.bigint "image_id"
    t.bigint "bundle_id"
    t.bigint "order_item_id"
    t.integer "slot_position"
    t.index ["bundle_id", "slot_position"], name: "index_variant_mappings_on_bundle_and_position", unique: true, where: "(bundle_id IS NOT NULL)"
    t.index ["bundle_id"], name: "index_variant_mappings_on_bundle_id"
    t.index ["frame_sku_code"], name: "index_variant_mappings_on_frame_sku_code"
    t.index ["frame_sku_cost_cents"], name: "index_variant_mappings_on_frame_sku_cost_cents"
    t.index ["frame_sku_id"], name: "index_variant_mappings_on_frame_sku_id"
    t.index ["image_id"], name: "index_variant_mappings_on_image_id"
    t.index ["order_item_id", "slot_position"], name: "index_variant_mappings_on_order_item_and_position", unique: true, where: "(order_item_id IS NOT NULL)"
    t.index ["order_item_id"], name: "index_variant_mappings_on_order_item_id"
    t.index ["product_variant_id", "country_code", "is_default"], name: "idx_variant_mappings_default_per_country", unique: true, where: "(is_default = true)"
    t.index ["product_variant_id", "country_code"], name: "index_variant_mappings_on_product_variant_id_and_country_code"
    t.index ["product_variant_id"], name: "index_variant_mappings_on_product_variant_id"
  end

  create_table "webhook_logs", force: :cascade do |t|
    t.string "topic", null: false
    t.string "shop_domain"
    t.bigint "store_id"
    t.integer "status_code", default: 0, null: false
    t.string "webhook_id"
    t.text "error_message"
    t.json "headers"
    t.text "payload_ciphertext"
    t.integer "processing_time_ms"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_webhook_logs_on_created_at"
    t.index ["shop_domain"], name: "index_webhook_logs_on_shop_domain"
    t.index ["status_code"], name: "index_webhook_logs_on_status_code"
    t.index ["store_id"], name: "index_webhook_logs_on_store_id"
    t.index ["topic"], name: "index_webhook_logs_on_topic"
    t.index ["webhook_id"], name: "index_webhook_logs_on_webhook_id", unique: true
  end

  add_foreign_key "bulk_mapping_requests", "stores"
  add_foreign_key "bundles", "product_variants"
  add_foreign_key "custom_print_sizes", "users"
  add_foreign_key "fulfillment_line_items", "fulfillments"
  add_foreign_key "fulfillment_line_items", "order_items"
  add_foreign_key "fulfillments", "orders"
  add_foreign_key "order_activities", "orders"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "product_variants"
  add_foreign_key "order_items", "variant_mappings"
  add_foreign_key "orders", "stores"
  add_foreign_key "orders", "users"
  add_foreign_key "product_variants", "products"
  add_foreign_key "products", "stores"
  add_foreign_key "saved_items", "custom_print_sizes"
  add_foreign_key "saved_items", "users"
  add_foreign_key "shipping_addresses", "orders"
  add_foreign_key "shopify_customers", "companies"
  add_foreign_key "shopify_customers", "users"
  add_foreign_key "stores", "organizations"
  add_foreign_key "stores", "users", column: "created_by_user_id"
  add_foreign_key "users", "organizations"
  add_foreign_key "variant_mappings", "bundles"
  add_foreign_key "variant_mappings", "images"
  add_foreign_key "variant_mappings", "order_items"
  add_foreign_key "variant_mappings", "product_variants"
  add_foreign_key "webhook_logs", "stores"
end
