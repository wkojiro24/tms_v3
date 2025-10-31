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

ActiveRecord::Schema[7.2].define(version: 2025_10_31_045022) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "employee_assignments", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "department"
    t.string "location"
    t.string "employment_type"
    t.string "position_title"
    t.date "effective_from", null: false
    t.date "effective_to"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "idx_employee_assignments_employee_from"
    t.index ["employee_id"], name: "index_employee_assignments_on_employee_id"
  end

  create_table "employee_positions", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "title"
    t.string "grade"
    t.date "effective_from", null: false
    t.date "effective_to"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "idx_employee_positions_employee_from"
    t.index ["employee_id"], name: "index_employee_positions_on_employee_id"
  end

  create_table "employee_qualifications", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "name", null: false
    t.string "issuer"
    t.date "acquired_on"
    t.date "expires_on"
    t.string "license_number"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "name"], name: "idx_employee_qualifications_employee_name"
    t.index ["employee_id"], name: "index_employee_qualifications_on_employee_id"
  end

  create_table "employee_reviews", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.date "reviewed_on", null: false
    t.string "review_cycle"
    t.decimal "score", precision: 5, scale: 2
    t.string "grade"
    t.text "summary"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "reviewed_on"], name: "idx_employee_reviews_employee_reviewed_on"
    t.index ["employee_id"], name: "index_employee_reviews_on_employee_id"
  end

  create_table "employee_statuses", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.string "status", null: false
    t.string "reason"
    t.date "effective_from", null: false
    t.date "effective_to"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "effective_from"], name: "idx_employee_statuses_employee_from"
    t.index ["employee_id"], name: "index_employee_statuses_on_employee_id"
  end

  create_table "employees", force: :cascade do |t|
    t.string "employee_code", limit: 50, null: false
    t.string "last_name"
    t.string "first_name"
    t.string "last_name_kana"
    t.string "first_name_kana"
    t.string "full_name"
    t.date "date_of_birth"
    t.date "hire_date"
    t.string "email"
    t.string "phone"
    t.string "current_status", default: "active", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_code"], name: "index_employees_on_employee_code", unique: true
  end

  create_table "item_orders", force: :cascade do |t|
    t.bigint "period_id", null: false
    t.string "location"
    t.bigint "item_id", null: false
    t.integer "row_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_item_orders_on_item_id"
    t.index ["period_id", "location", "item_id"], name: "idx_item_orders_period_location_item", unique: true
    t.index ["period_id", "location", "row_index"], name: "idx_item_orders_period_location_row", unique: true
    t.index ["period_id"], name: "index_item_orders_on_period_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.integer "position"
    t.integer "row_index"
    t.boolean "above_basic", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name", "above_basic"], name: "index_items_on_name_and_above_basic", unique: true
    t.index ["name"], name: "index_items_on_name"
  end

  create_table "payroll_batches", force: :cascade do |t|
    t.bigint "period_id", null: false
    t.string "location"
    t.string "title"
    t.string "original_filename"
    t.string "status", default: "pending", null: false
    t.bigint "uploaded_by_id", null: false
    t.integer "total_rows", default: 0
    t.integer "total_cells", default: 0
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["period_id", "location"], name: "idx_payroll_batches_period_location"
    t.index ["period_id"], name: "index_payroll_batches_on_period_id"
    t.index ["uploaded_by_id"], name: "index_payroll_batches_on_uploaded_by_id"
  end

  create_table "payroll_cells", force: :cascade do |t|
    t.bigint "period_id", null: false
    t.bigint "employee_id", null: false
    t.bigint "item_id", null: false
    t.bigint "payroll_batch_id", null: false
    t.string "location"
    t.string "raw"
    t.decimal "amount", precision: 15, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_payroll_cells_on_employee_id"
    t.index ["item_id"], name: "index_payroll_cells_on_item_id"
    t.index ["payroll_batch_id"], name: "index_payroll_cells_on_payroll_batch_id"
    t.index ["period_id", "location", "employee_id", "item_id"], name: "idx_payroll_cells_unique", unique: true
    t.index ["period_id"], name: "index_payroll_cells_on_period_id"
  end

  create_table "payroll_column_orders", force: :cascade do |t|
    t.bigint "period_id", null: false
    t.string "location"
    t.bigint "employee_id", null: false
    t.integer "column_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_payroll_column_orders_on_employee_id"
    t.index ["period_id", "location", "column_index"], name: "idx_payroll_column_orders_period_col", unique: true
    t.index ["period_id", "location", "employee_id"], name: "idx_payroll_column_orders_unique", unique: true
    t.index ["period_id"], name: "index_payroll_column_orders_on_period_id"
  end

  create_table "periods", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "month", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["year", "month"], name: "index_periods_on_year_and_month", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "role", default: "staff", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "employee_assignments", "employees"
  add_foreign_key "employee_positions", "employees"
  add_foreign_key "employee_qualifications", "employees"
  add_foreign_key "employee_reviews", "employees"
  add_foreign_key "employee_statuses", "employees"
  add_foreign_key "item_orders", "items"
  add_foreign_key "item_orders", "periods"
  add_foreign_key "payroll_batches", "periods"
  add_foreign_key "payroll_batches", "users", column: "uploaded_by_id"
  add_foreign_key "payroll_cells", "employees"
  add_foreign_key "payroll_cells", "items"
  add_foreign_key "payroll_cells", "payroll_batches"
  add_foreign_key "payroll_cells", "periods"
  add_foreign_key "payroll_column_orders", "employees"
  add_foreign_key "payroll_column_orders", "periods"
end
