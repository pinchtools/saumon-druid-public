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

ActiveRecord::Schema[8.1].define(version: 2025_12_12_100104) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "pg_trgm"
  enable_extension "vector"

  create_table "agent_version_llm_models", force: :cascade do |t|
    t.bigint "agent_version_id", null: false
    t.datetime "created_at", null: false
    t.boolean "enabled", default: true, null: false
    t.bigint "llm_model_id", null: false
    t.integer "priority", default: 1, null: false
    t.datetime "updated_at", null: false
    t.index ["agent_version_id", "llm_model_id"], name: "idx_on_agent_version_id_llm_model_id_6916d77c45", unique: true
    t.index ["agent_version_id", "priority"], name: "idx_on_agent_version_id_priority_43756bb370", unique: true
    t.index ["agent_version_id"], name: "index_agent_version_llm_models_on_agent_version_id"
    t.index ["llm_model_id"], name: "index_agent_version_llm_models_on_llm_model_id"
  end

  create_table "agent_versions", force: :cascade do |t|
    t.bigint "agent_id", null: false
    t.datetime "created_at", null: false
    t.jsonb "hyperparams"
    t.jsonb "instructions"
    t.datetime "updated_at", null: false
    t.integer "version", default: 1, null: false
    t.index ["agent_id", "version"], name: "index_agent_versions_on_agent_id_and_version", unique: true
    t.index ["agent_id"], name: "index_agent_versions_on_agent_id"
  end

  create_table "agents", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.bigint "current_agent_version_id"
    t.text "description"
    t.string "name", null: false
    t.string "normalized_name", null: false
    t.datetime "updated_at", null: false
    t.index ["current_agent_version_id"], name: "index_agents_on_current_agent_version_id"
    t.index ["normalized_name"], name: "index_agents_on_normalized_name", unique: true
  end

  create_table "an_bodies", force: :cascade do |t|
    t.bigint "an_body_type_id", null: false
    t.string "chamber"
    t.datetime "created_at", null: false
    t.datetime "deliver_date"
    t.string "department_code"
    t.datetime "end_date"
    t.string "label"
    t.string "label_abbr"
    t.string "label_code"
    t.string "legislature"
    t.string "number"
    t.bigint "parent_id"
    t.string "province"
    t.string "regime"
    t.datetime "start_date"
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["an_body_type_id"], name: "index_an_bodies_on_an_body_type_id"
    t.index ["parent_id"], name: "index_an_bodies_on_parent_id"
    t.index ["uid"], name: "index_an_bodies_on_uid", unique: true
  end

  create_table "an_bodies_countries", id: false, force: :cascade do |t|
    t.bigint "an_body_id", null: false
    t.bigint "an_country_id", null: false
    t.index ["an_body_id", "an_country_id"], name: "index_an_bodies_countries_on_an_body_id_and_an_country_id", unique: true
  end

  create_table "an_body_types", force: :cascade do |t|
    t.string "code"
    t.datetime "created_at", null: false
    t.boolean "external", default: false, null: false
    t.string "group"
    t.boolean "has_substitute", default: false, null: false
    t.integer "hierarchy_level"
    t.string "institution"
    t.boolean "local", default: false, null: false
    t.string "selection"
    t.boolean "single_assignment_per_actor", default: false, null: false
    t.boolean "trans_legislature", default: false, null: false
    t.boolean "unique_per_date", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_an_body_types_on_code", unique: true
  end

  create_table "an_corrections", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.bigint "correctable_id", null: false
    t.string "correctable_type", null: false
    t.jsonb "correction_changes", default: {}, null: false
    t.string "correction_type", default: "automatic", null: false
    t.datetime "created_at", null: false
    t.string "reason", null: false
    t.string "session_id"
    t.datetime "updated_at", null: false
    t.index ["correctable_type", "correctable_id", "created_at"], name: "idx_corrections_on_correctable_and_time"
    t.index ["correctable_type", "correctable_id"], name: "index_an_corrections_on_correctable"
    t.index ["correction_changes"], name: "index_an_corrections_on_correction_changes", using: :gin
    t.index ["created_at"], name: "index_an_corrections_on_created_at"
    t.index ["session_id"], name: "index_an_corrections_on_session_id"
    t.check_constraint "correctable_type::text = ANY (ARRAY['An::Stakeholder'::character varying, 'An::Term'::character varying, 'An::Body'::character varying]::text[])", name: "check_correctable_type"
  end

  create_table "an_countries", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "insee_code"
    t.string "insee_name"
    t.string "iso_code"
    t.string "name", null: false
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_an_countries_on_name"
    t.index ["uid"], name: "index_an_countries_on_uid", unique: true
  end

  create_table "an_searches", id: :uuid, default: -> { "uuidv7()" }, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.vector "embedding", limit: 1024
    t.tsvector "fts"
    t.bigint "searchable_id", null: false
    t.string "searchable_type", null: false
    t.text "trigram"
    t.datetime "updated_at", null: false
    t.index ["embedding"], name: "index_an_searches_on_embedding", opclass: :vector_cosine_ops, using: :hnsw
    t.index ["fts"], name: "index_an_searches_on_fts", using: :gin
    t.index ["searchable_type", "searchable_id"], name: "index_an_searches_on_searchable"
    t.index ["searchable_type", "searchable_id"], name: "index_an_searches_on_searchable_type_and_searchable_id", unique: true
    t.index ["trigram"], name: "index_an_searches_on_trigram", opclass: :gin_trgm_ops, using: :gin
  end

  create_table "an_stakeholder_addresses", force: :cascade do |t|
    t.string "address_1"
    t.string "address_2"
    t.string "address_type"
    t.bigint "an_stakeholder_id", null: false
    t.string "city"
    t.datetime "created_at", null: false
    t.string "post_code"
    t.string "street_name"
    t.string "street_number"
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.integer "weight"
    t.index ["an_stakeholder_id"], name: "index_an_stakeholder_addresses_on_an_stakeholder_id"
    t.index ["uid"], name: "index_an_stakeholder_addresses_on_uid", unique: true
  end

  create_table "an_stakeholders", force: :cascade do |t|
    t.string "birth_city"
    t.string "birth_country"
    t.date "birth_date"
    t.string "birth_province"
    t.string "civility"
    t.datetime "created_at", null: false
    t.date "death_date"
    t.string "emails", default: [], array: true
    t.string "first_name"
    t.string "gender"
    t.string "last_name"
    t.string "occupation"
    t.string "occupation_category"
    t.string "occupation_family"
    t.string "phone_numbers", default: [], array: true
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.string "urls", default: [], array: true
    t.index ["birth_date"], name: "index_an_stakeholders_on_birth_date"
    t.index ["first_name"], name: "index_an_stakeholders_on_first_name"
    t.index ["last_name"], name: "index_an_stakeholders_on_last_name"
    t.index ["occupation"], name: "index_an_stakeholders_on_occupation"
    t.index ["occupation_category"], name: "index_an_stakeholders_on_occupation_category"
    t.index ["occupation_family"], name: "index_an_stakeholders_on_occupation_family"
    t.index ["uid"], name: "index_an_stakeholders_on_uid", unique: true
  end

  create_table "an_substitutes", force: :cascade do |t|
    t.bigint "an_stakeholder_id", null: false
    t.bigint "an_term_id", null: false
    t.datetime "created_at", null: false
    t.datetime "end_date"
    t.datetime "start_date"
    t.datetime "updated_at", null: false
    t.index ["an_stakeholder_id"], name: "index_an_substitutes_on_an_stakeholder_id"
    t.index ["an_term_id"], name: "index_an_substitutes_on_an_term_id"
  end

  create_table "an_terms", force: :cascade do |t|
    t.bigint "an_body_id", null: false
    t.bigint "an_stakeholder_id", null: false
    t.datetime "assumption_date"
    t.string "capacity"
    t.string "collaborators", default: [], array: true
    t.bigint "constituency_id"
    t.datetime "created_at", null: false
    t.bigint "deputy_term_id"
    t.datetime "end_date"
    t.string "end_reason"
    t.string "label", limit: 800
    t.string "legislature"
    t.boolean "main", default: false, null: false
    t.string "origin"
    t.datetime "publish_date"
    t.integer "role_rank"
    t.string "seat"
    t.datetime "start_date"
    t.string "uid", null: false
    t.datetime "updated_at", null: false
    t.index ["an_body_id"], name: "index_an_terms_on_an_body_id"
    t.index ["an_stakeholder_id", "end_date", "start_date"], name: "index_an_terms_by_stakeholder_active", where: "((start_date IS NOT NULL) AND (end_date IS NULL))"
    t.index ["an_stakeholder_id", "start_date", "end_date"], name: "index_an_terms_by_stakeholder_past", where: "((start_date IS NOT NULL) AND (end_date IS NOT NULL))"
    t.index ["an_stakeholder_id"], name: "index_an_terms_on_an_stakeholder_id"
    t.index ["constituency_id"], name: "index_an_terms_on_constituency_id"
    t.index ["deputy_term_id"], name: "index_an_terms_on_deputy_term_id"
    t.index ["start_date", "end_date"], name: "index_terms_on_dates"
    t.index ["uid"], name: "index_an_terms_on_uid", unique: true
  end

  create_table "llm_models", force: :cascade do |t|
    t.boolean "available", default: true
    t.jsonb "capabilities", default: []
    t.jsonb "categories", default: []
    t.integer "context_window"
    t.datetime "created_at", null: false
    t.string "external_id", null: false
    t.string "family", null: false
    t.boolean "free", default: false
    t.decimal "input_cost", precision: 10, scale: 6
    t.date "knowledge_cutoff"
    t.string "name", null: false
    t.decimal "output_cost", precision: 10, scale: 6
    t.integer "output_size"
    t.string "provider", null: false
    t.jsonb "supported_params", default: []
    t.string "tier"
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_llm_models_on_external_id", unique: true
    t.index ["family"], name: "index_llm_models_on_family"
    t.index ["tier"], name: "index_llm_models_on_tier"
    t.check_constraint "tier::text = ANY (ARRAY['tiny'::character varying, 'small'::character varying, 'medium'::character varying, 'strong'::character varying, 'top'::character varying]::text[])", name: "valid_tier"
  end

  add_foreign_key "agent_version_llm_models", "agent_versions"
  add_foreign_key "agent_version_llm_models", "llm_models"
  add_foreign_key "agent_versions", "agents"
  add_foreign_key "agents", "agent_versions", column: "current_agent_version_id"
  add_foreign_key "an_bodies", "an_bodies", column: "parent_id"
  add_foreign_key "an_bodies", "an_body_types"
  add_foreign_key "an_bodies_countries", "an_bodies", on_delete: :cascade
  add_foreign_key "an_bodies_countries", "an_countries", on_delete: :cascade
  add_foreign_key "an_stakeholder_addresses", "an_stakeholders"
  add_foreign_key "an_substitutes", "an_stakeholders"
  add_foreign_key "an_substitutes", "an_terms"
  add_foreign_key "an_terms", "an_bodies"
  add_foreign_key "an_terms", "an_bodies", column: "constituency_id"
  add_foreign_key "an_terms", "an_stakeholders"
  add_foreign_key "an_terms", "an_terms", column: "deputy_term_id"
end
