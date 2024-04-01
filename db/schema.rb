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

ActiveRecord::Schema[7.1].define(version: 2024_03_20_020209) do
  create_table "checksum_algorithms", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.binary "empty_binary_value", null: false
    t.index ["name"], name: "index_checksum_algorithms_on_name", unique: true
  end

  create_table "fixity_verifications", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "source_object_id", null: false
    t.bigint "stored_object_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_object_id"], name: "index_fixity_verifications_on_source_object_id"
    t.index ["status"], name: "index_fixity_verifications_on_status"
    t.index ["stored_object_id"], name: "index_fixity_verifications_on_stored_object_id"
  end

  create_table "pending_transfers", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "transfer_checksum_algorithm_id", null: false
    t.binary "transfer_checksum_value", limit: 4, null: false
    t.integer "transfer_checksum_part_size"
    t.integer "transfer_checksum_part_count"
    t.bigint "storage_provider_id", null: false
    t.bigint "source_object_id", null: false
    t.integer "status", default: 0, null: false
    t.text "error_message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "stored_object_path", limit: 1024
    t.binary "stored_object_path_hash", limit: 32
    t.index ["source_object_id", "storage_provider_id"], name: "idx_on_source_object_id_storage_provider_id_c884dc9313", unique: true
    t.index ["source_object_id"], name: "index_pending_transfers_on_source_object_id"
    t.index ["storage_provider_id"], name: "index_pending_transfers_on_storage_provider_id"
    t.index ["transfer_checksum_algorithm_id"], name: "index_pending_transfers_on_transfer_checksum_algorithm_id"
    t.index ["transfer_checksum_part_count"], name: "index_pending_transfers_on_transfer_checksum_part_count"
    t.index ["transfer_checksum_part_size"], name: "index_pending_transfers_on_transfer_checksum_part_size"
  end

  create_table "repositories", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "source_objects", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "path", limit: 4096, null: false
    t.binary "path_hash", limit: 32, null: false
    t.bigint "object_size", null: false
    t.datetime "on_prem_deleted_at"
    t.bigint "repository_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "fixity_checksum_algorithm_id"
    t.binary "fixity_checksum_value", limit: 64
    t.index ["fixity_checksum_algorithm_id"], name: "index_source_objects_on_fixity_checksum_algorithm_id"
    t.index ["fixity_checksum_value"], name: "index_source_objects_on_fixity_checksum_value"
    t.index ["path_hash"], name: "index_source_objects_on_path_hash", unique: true
    t.index ["repository_id"], name: "index_source_objects_on_repository_id"
  end

  create_table "storage_providers", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.integer "storage_type", null: false
    t.string "container_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["container_name"], name: "index_storage_providers_on_container_name"
    t.index ["storage_type", "container_name"], name: "index_storage_providers_on_storage_type_and_container_name", unique: true
    t.index ["storage_type"], name: "index_storage_providers_on_storage_type"
  end

  create_table "stored_objects", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "path", limit: 1024, null: false
    t.binary "path_hash", limit: 32, null: false
    t.bigint "source_object_id", null: false
    t.bigint "storage_provider_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "transfer_checksum_algorithm_id"
    t.binary "transfer_checksum_value", limit: 4
    t.integer "transfer_checksum_part_size"
    t.integer "transfer_checksum_part_count"
    t.index ["source_object_id"], name: "index_stored_objects_on_source_object_id"
    t.index ["storage_provider_id", "path_hash"], name: "index_stored_objects_on_storage_provider_id_and_path_hash", unique: true
    t.index ["storage_provider_id", "source_object_id"], name: "idx_on_storage_provider_id_source_object_id_25088e9be4", unique: true
    t.index ["storage_provider_id"], name: "index_stored_objects_on_storage_provider_id"
    t.index ["transfer_checksum_algorithm_id"], name: "index_stored_objects_on_transfer_checksum_algorithm_id"
    t.index ["transfer_checksum_part_count"], name: "index_stored_objects_on_transfer_checksum_part_count"
    t.index ["transfer_checksum_part_size"], name: "index_stored_objects_on_transfer_checksum_part_size"
    t.index ["transfer_checksum_value"], name: "index_stored_objects_on_transfer_checksum_value"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uid"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["uid"], name: "index_users_on_uid", unique: true
  end

  add_foreign_key "pending_transfers", "checksum_algorithms", column: "transfer_checksum_algorithm_id"
  add_foreign_key "source_objects", "checksum_algorithms", column: "fixity_checksum_algorithm_id"
  add_foreign_key "stored_objects", "checksum_algorithms", column: "transfer_checksum_algorithm_id"
end
