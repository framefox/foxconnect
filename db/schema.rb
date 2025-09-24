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

ActiveRecord::Schema[8.0].define(version: 2025_09_23_040100) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "product_variants", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.bigint "external_variant_id", null: false
    t.string "title", null: false
    t.string "sku"
    t.string "barcode"
    t.integer "position", default: 1
    t.decimal "price", precision: 10, scale: 2, null: false
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
    t.index ["available_for_sale"], name: "index_product_variants_on_available_for_sale"
    t.index ["barcode"], name: "index_product_variants_on_barcode"
    t.index ["position"], name: "index_product_variants_on_position"
    t.index ["product_id", "external_variant_id"], name: "index_product_variants_on_product_id_and_external_variant_id", unique: true
    t.index ["product_id", "position"], name: "index_product_variants_on_product_id_and_position"
    t.index ["product_id"], name: "index_product_variants_on_product_id"
    t.index ["sku"], name: "index_product_variants_on_sku"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "external_id", null: false
    t.string "platform", null: false
    t.string "title", null: false
    t.text "description"
    t.text "description_html"
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
    t.index ["handle"], name: "index_products_on_handle"
    t.index ["platform", "external_id"], name: "index_products_on_platform_and_external_id", unique: true
    t.index ["platform"], name: "index_products_on_platform"
    t.index ["product_type"], name: "index_products_on_product_type"
    t.index ["status"], name: "index_products_on_status"
    t.index ["title"], name: "index_products_on_title"
    t.index ["vendor"], name: "index_products_on_vendor"
  end

  create_table "stores", force: :cascade do |t|
    t.string "name", null: false
    t.string "platform", default: "shopify", null: false
    t.string "shopify_domain", null: false
    t.string "shopify_token"
    t.string "access_scopes"
    t.json "settings", default: {}
    t.boolean "active", default: true
    t.datetime "last_sync_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["platform", "active"], name: "index_stores_on_platform_and_active"
    t.index ["platform"], name: "index_stores_on_platform"
    t.index ["shopify_domain"], name: "index_stores_on_shopify_domain", unique: true
  end

  add_foreign_key "product_variants", "products"
end
