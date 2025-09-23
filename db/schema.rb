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

ActiveRecord::Schema[8.0].define(version: 2025_09_23_035000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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
end
