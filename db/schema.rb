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

ActiveRecord::Schema[8.0].define(version: 2025_10_06_141635) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "an_body_types", force: :cascade do |t|
    t.string "code"
    t.boolean "unique_per_date", default: false, null: false
    t.boolean "single_assignment_per_actor", default: false, null: false
    t.boolean "external", default: false, null: false
    t.boolean "trans_legislature", default: false, null: false
    t.boolean "local", default: false, null: false
    t.boolean "has_substitute", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_an_body_types_on_code", unique: true
  end

  create_table "an_stakeholder_addresses", force: :cascade do |t|
    t.bigint "an_stakeholder_id", null: false
    t.string "uid", null: false
    t.string "address_1"
    t.string "address_2"
    t.string "street_name"
    t.string "street_number"
    t.string "post_code"
    t.string "city"
    t.integer "weight"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["an_stakeholder_id"], name: "index_an_stakeholder_addresses_on_an_stakeholder_id"
    t.index ["uid"], name: "index_an_stakeholder_addresses_on_uid", unique: true
  end

  create_table "an_stakeholders", force: :cascade do |t|
    t.string "uid"
    t.string "civility"
    t.string "first_name"
    t.string "last_name"
    t.date "birth_date"
    t.string "birth_city"
    t.string "birth_province"
    t.date "death_date"
    t.string "occupation"
    t.string "occupation_category"
    t.string "occupation_family"
    t.string "emails", default: [], array: true
    t.string "urls", default: [], array: true
    t.string "phone_numbers", default: [], array: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["birth_date"], name: "index_an_stakeholders_on_birth_date"
    t.index ["first_name"], name: "index_an_stakeholders_on_first_name"
    t.index ["last_name"], name: "index_an_stakeholders_on_last_name"
    t.index ["occupation"], name: "index_an_stakeholders_on_occupation"
    t.index ["occupation_category"], name: "index_an_stakeholders_on_occupation_category"
    t.index ["occupation_family"], name: "index_an_stakeholders_on_occupation_family"
    t.index ["uid"], name: "index_an_stakeholders_on_uid", unique: true
  end

  add_foreign_key "an_stakeholder_addresses", "an_stakeholders"
end
