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

ActiveRecord::Schema[7.1].define(version: 2024_03_04_185420) do
  create_table "checksum_algorithms", force: :cascade do |t|
    t.string "name", null: false
    t.string "empty_value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["empty_value"], name: "index_checksum_algorithms_on_empty_value", unique: true
    t.index ["name"], name: "index_checksum_algorithms_on_name", unique: true
  end

  create_table "checksums", force: :cascade do |t|
    t.string "value", null: false
    t.integer "checksum_algorithm_id", null: false
    t.integer "chunk_size"
    t.integer "transfer_source_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checksum_algorithm_id"], name: "index_checksums_on_checksum_algorithm_id"
    t.index ["transfer_source_id"], name: "index_checksums_on_transfer_source_id"
  end

  create_table "object_transfers", force: :cascade do |t|
    t.string "path", limit: 4096, null: false
    t.binary "path_hash", limit: 32, null: false
    t.integer "transfer_source_id", null: false
    t.integer "storage_provider_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["storage_provider_id", "path_hash"], name: "index_object_transfers_on_storage_provider_id_and_path_hash", unique: true
    t.index ["storage_provider_id"], name: "index_object_transfers_on_storage_provider_id"
    t.index ["transfer_source_id"], name: "index_object_transfers_on_transfer_source_id"
  end

  create_table "repositories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "storage_providers", force: :cascade do |t|
    t.integer "storage_type", null: false
    t.string "container_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["container_name"], name: "index_storage_providers_on_container_name"
    t.index ["storage_type", "container_name"], name: "index_storage_providers_on_storage_type_and_container_name", unique: true
    t.index ["storage_type"], name: "index_storage_providers_on_storage_type"
  end

  create_table "transfer_sources", force: :cascade do |t|
    t.string "path", limit: 4096, null: false
    t.binary "path_hash", limit: 32, null: false
    t.bigint "object_size", null: false
    t.datetime "on_prem_deleted_at"
    t.integer "repository_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["path_hash"], name: "index_transfer_sources_on_path_hash", unique: true
    t.index ["repository_id"], name: "index_transfer_sources_on_repository_id"
  end

  create_table "transfer_verifications", force: :cascade do |t|
    t.string "checksum_value", null: false
    t.integer "checksum_algorithm_id", null: false
    t.integer "checksum_chunk_size"
    t.bigint "object_size", null: false
    t.integer "object_transfer_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["checksum_algorithm_id"], name: "index_transfer_verifications_on_checksum_algorithm_id"
    t.index ["object_transfer_id"], name: "index_transfer_verifications_on_object_transfer_id"
  end

  add_foreign_key "checksums", "checksum_algorithms"
  add_foreign_key "checksums", "transfer_sources"
  add_foreign_key "object_transfers", "storage_providers"
  add_foreign_key "object_transfers", "transfer_sources"
  add_foreign_key "transfer_verifications", "checksum_algorithms"
  add_foreign_key "transfer_verifications", "object_transfers"
end
