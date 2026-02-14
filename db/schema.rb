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

ActiveRecord::Schema[7.2].define(version: 2026_02_14_053933) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
    t.index ["blob_id"], name: "index_active_storage_variant_records_on_blob_id"
  end

  create_table "announcements", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.text "body"
    t.string "category", default: "general"
    t.datetime "published_at"
    t.datetime "expires_at"
    t.boolean "pinned", default: false
    t.bigint "author_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "event_date"
    t.date "event_end_date"
    t.string "event_location"
    t.boolean "all_day"
    t.index ["author_id"], name: "index_announcements_on_author_id"
    t.index ["tenant_id", "category"], name: "index_announcements_on_tenant_id_and_category"
    t.index ["tenant_id", "published_at"], name: "index_announcements_on_tenant_id_and_published_at"
    t.index ["tenant_id"], name: "index_announcements_on_tenant_id"
  end

  create_table "attendance_monthlies", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "employee_id"
    t.string "employee_code", null: false
    t.string "employee_name"
    t.string "department_name"
    t.integer "year", null: false
    t.integer "month", null: false
    t.decimal "working_days", precision: 5, scale: 2
    t.decimal "holiday_working_days", precision: 5, scale: 2
    t.decimal "substitute_days", precision: 5, scale: 2
    t.decimal "extra_holiday_days", precision: 5, scale: 2
    t.decimal "paid_leave_days", precision: 5, scale: 2
    t.decimal "absent_days", precision: 5, scale: 2
    t.decimal "total_hours", precision: 6, scale: 2
    t.decimal "break_hours", precision: 5, scale: 2
    t.decimal "overtime_hours", precision: 5, scale: 2
    t.decimal "holiday_hours", precision: 5, scale: 2
    t.decimal "extra_holiday_hours", precision: 5, scale: 2
    t.decimal "substitute_holiday_hours", precision: 5, scale: 2
    t.decimal "extra_substitute_hours", precision: 5, scale: 2
    t.decimal "scheduled_overtime", precision: 5, scale: 2
    t.decimal "paid_leave_hours", precision: 5, scale: 2
    t.decimal "late_night_hours", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_attendance_monthlies_on_employee_id"
    t.index ["tenant_id", "employee_code", "year", "month"], name: "idx_attendance_monthly_tenant_emp_ym", unique: true
    t.index ["tenant_id", "year", "month"], name: "index_attendance_monthlies_on_tenant_id_and_year_and_month"
    t.index ["tenant_id"], name: "index_attendance_monthlies_on_tenant_id"
  end

  create_table "attendance_records", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "employee_id"
    t.string "employee_code", null: false
    t.string "employee_name"
    t.date "work_date", null: false
    t.string "day_type"
    t.string "time_zone_category"
    t.string "pattern_name"
    t.time "clock_in"
    t.time "clock_out"
    t.string "work_location"
    t.decimal "break_hours", precision: 5, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_attendance_records_on_employee_id"
    t.index ["tenant_id", "employee_code", "work_date"], name: "idx_attendance_tenant_emp_date", unique: true
    t.index ["tenant_id", "work_date"], name: "index_attendance_records_on_tenant_id_and_work_date"
    t.index ["tenant_id"], name: "index_attendance_records_on_tenant_id"
  end

  create_table "bookmarks", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "title", null: false
    t.string "url", null: false
    t.text "description"
    t.string "category", default: "general"
    t.string "icon"
    t.integer "position", default: 0
    t.boolean "shared", default: true
    t.bigint "creator_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_bookmarks_on_creator_id"
    t.index ["tenant_id", "category"], name: "index_bookmarks_on_tenant_id_and_category"
    t.index ["tenant_id", "position"], name: "index_bookmarks_on_tenant_id_and_position"
    t.index ["tenant_id"], name: "index_bookmarks_on_tenant_id"
  end

  create_table "classification_rules", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "name", null: false
    t.integer "priority", default: 100, null: false
    t.string "nature", null: false
    t.decimal "split_ratio", precision: 5, scale: 2
    t.jsonb "conditions", default: {}, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "nature"], name: "index_classification_rules_on_tenant_id_and_nature"
    t.index ["tenant_id", "priority"], name: "index_classification_rules_on_tenant_id_and_priority"
    t.index ["tenant_id"], name: "index_classification_rules_on_tenant_id"
  end

  create_table "client_driver_policies", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "client_id", null: false
    t.bigint "driver_id", null: false
    t.integer "policy_type", default: 0
    t.string "reason"
    t.date "effective_from"
    t.date "effective_until"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_client_driver_policies_on_client_id"
    t.index ["driver_id"], name: "index_client_driver_policies_on_driver_id"
    t.index ["tenant_id", "client_id", "driver_id"], name: "idx_client_driver_policy_unique", unique: true
    t.index ["tenant_id", "driver_id"], name: "idx_client_driver_policy_driver"
    t.index ["tenant_id"], name: "index_client_driver_policies_on_tenant_id"
  end

  create_table "departments", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_departments_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_departments_on_tenant_id"
  end

  create_table "destinations", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "shipper_id"
    t.string "code", null: false
    t.string "name", null: false
    t.string "postal_code"
    t.string "address"
    t.string "phone"
    t.decimal "latitude", precision: 10, scale: 7
    t.decimal "longitude", precision: 10, scale: 7
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shipper_id"], name: "index_destinations_on_shipper_id"
    t.index ["tenant_id", "code"], name: "index_destinations_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_destinations_on_tenant_id"
  end

  create_table "dispatch_assignments", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "dispatch_plan_id", null: false
    t.bigint "vehicle_id"
    t.bigint "employee_id"
    t.bigint "shipper_id"
    t.bigint "origin_location_id"
    t.bigint "destination_location_id"
    t.integer "sequence", default: 1, null: false
    t.time "scheduled_departure"
    t.time "scheduled_arrival"
    t.time "estimated_return"
    t.string "product_name"
    t.string "cargo_type"
    t.string "instruction"
    t.text "route_instruction"
    t.text "remarks"
    t.integer "status", default: 0, null: false
    t.boolean "delivery_slip_confirmed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "transport_order_id"
    t.boolean "alert_flag", default: false, null: false
    t.bigint "order_id"
    t.index ["destination_location_id"], name: "index_dispatch_assignments_on_destination_location_id"
    t.index ["dispatch_plan_id", "vehicle_id", "sequence"], name: "idx_dispatch_assignments_plan_vehicle_seq"
    t.index ["dispatch_plan_id"], name: "index_dispatch_assignments_on_dispatch_plan_id"
    t.index ["employee_id"], name: "index_dispatch_assignments_on_employee_id"
    t.index ["order_id"], name: "index_dispatch_assignments_on_order_id"
    t.index ["origin_location_id"], name: "index_dispatch_assignments_on_origin_location_id"
    t.index ["shipper_id"], name: "index_dispatch_assignments_on_shipper_id"
    t.index ["tenant_id"], name: "index_dispatch_assignments_on_tenant_id"
    t.index ["transport_order_id"], name: "index_dispatch_assignments_on_transport_order_id"
    t.index ["vehicle_id"], name: "index_dispatch_assignments_on_vehicle_id"
  end

  create_table "dispatch_plans", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.date "date", null: false
    t.text "notes"
    t.integer "status", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "vehicle_memos"
    t.string "share_token"
    t.datetime "share_token_expires_at"
    t.index ["tenant_id", "date"], name: "index_dispatch_plans_on_tenant_id_and_date", unique: true
    t.index ["tenant_id"], name: "index_dispatch_plans_on_tenant_id"
  end

  create_table "driver_daily_statuses", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "driver_id", null: false
    t.bigint "plan_vehicle_id"
    t.bigint "plan_client_id"
    t.bigint "actual_vehicle_id"
    t.date "date", null: false
    t.integer "plan_status", default: 0
    t.integer "actual_status"
    t.string "reason"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["actual_vehicle_id"], name: "index_driver_daily_statuses_on_actual_vehicle_id"
    t.index ["driver_id"], name: "index_driver_daily_statuses_on_driver_id"
    t.index ["plan_client_id"], name: "index_driver_daily_statuses_on_plan_client_id"
    t.index ["plan_vehicle_id"], name: "index_driver_daily_statuses_on_plan_vehicle_id"
    t.index ["tenant_id", "date", "plan_status"], name: "idx_driver_daily_status_date"
    t.index ["tenant_id", "driver_id", "date"], name: "idx_driver_daily_status_unique", unique: true
    t.index ["tenant_id"], name: "index_driver_daily_statuses_on_tenant_id"
  end

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
    t.bigint "tenant_id", null: false
    t.index ["employee_id", "effective_from"], name: "idx_employee_assignments_employee_from"
    t.index ["employee_id"], name: "index_employee_assignments_on_employee_id"
    t.index ["tenant_id"], name: "index_employee_assignments_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.index ["employee_id", "effective_from"], name: "idx_employee_positions_employee_from"
    t.index ["employee_id"], name: "index_employee_positions_on_employee_id"
    t.index ["tenant_id"], name: "index_employee_positions_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.index ["employee_id", "name"], name: "idx_employee_qualifications_employee_name"
    t.index ["employee_id"], name: "index_employee_qualifications_on_employee_id"
    t.index ["tenant_id"], name: "index_employee_qualifications_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.bigint "evaluation_cycle_id"
    t.bigint "grade_level_id"
    t.bigint "evaluation_grade_id"
    t.index ["employee_id", "reviewed_on"], name: "idx_employee_reviews_employee_reviewed_on"
    t.index ["employee_id"], name: "index_employee_reviews_on_employee_id"
    t.index ["evaluation_cycle_id"], name: "index_employee_reviews_on_evaluation_cycle_id"
    t.index ["evaluation_grade_id"], name: "index_employee_reviews_on_evaluation_grade_id"
    t.index ["grade_level_id"], name: "index_employee_reviews_on_grade_level_id"
    t.index ["tenant_id"], name: "index_employee_reviews_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.index ["employee_id", "effective_from"], name: "idx_employee_statuses_employee_from"
    t.index ["employee_id"], name: "index_employee_statuses_on_employee_id"
    t.index ["tenant_id"], name: "index_employee_statuses_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.boolean "submit_enabled", default: false, null: false
    t.bigint "department_id"
    t.bigint "job_category_id"
    t.bigint "job_position_id"
    t.bigint "grade_level_id"
    t.string "depot_name"
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["grade_level_id"], name: "index_employees_on_grade_level_id"
    t.index ["job_category_id"], name: "index_employees_on_job_category_id"
    t.index ["job_position_id"], name: "index_employees_on_job_position_id"
    t.index ["submit_enabled"], name: "index_employees_on_submit_enabled"
    t.index ["tenant_id", "department_id"], name: "index_employees_on_tenant_id_and_department_id"
    t.index ["tenant_id", "depot_name"], name: "index_employees_on_tenant_id_and_depot_name"
    t.index ["tenant_id", "employee_code"], name: "index_employees_on_tenant_and_employee_code", unique: true
    t.index ["tenant_id", "grade_level_id"], name: "index_employees_on_tenant_id_and_grade_level_id"
    t.index ["tenant_id", "job_category_id"], name: "index_employees_on_tenant_id_and_job_category_id"
    t.index ["tenant_id", "job_position_id"], name: "index_employees_on_tenant_id_and_job_position_id"
    t.index ["tenant_id"], name: "index_employees_on_tenant_id"
  end

  create_table "evaluation_cycles", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.date "start_on"
    t.date "end_on"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_evaluation_cycles_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_evaluation_cycles_on_tenant_id"
  end

  create_table "evaluation_grades", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "band"
    t.boolean "active", default: true, null: false
    t.integer "score"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_evaluation_grades_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_evaluation_grades_on_tenant_id"
  end

  create_table "external_economic_data", force: :cascade do |t|
    t.string "data_type", null: false
    t.integer "year", null: false
    t.integer "month"
    t.decimal "value", precision: 15, scale: 2
    t.string "region"
    t.string "source"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["data_type", "year", "month"], name: "index_external_economic_data_on_data_type_and_year_and_month"
    t.index ["data_type", "year", "region"], name: "index_external_economic_data_on_data_type_and_year_and_region"
  end

  create_table "grade_levels", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_grade_levels_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_grade_levels_on_tenant_id"
  end

  create_table "grade_salary_tables", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "grade_level_id"
    t.string "grade_code", null: false
    t.string "grade_name"
    t.integer "base_salary", default: 0, null: false
    t.integer "city_allowance", default: 0
    t.integer "hourly_rate"
    t.decimal "overtime_rate", precision: 4, scale: 2, default: "1.25"
    t.decimal "late_night_rate", precision: 4, scale: 2, default: "0.25"
    t.decimal "holiday_rate", precision: 4, scale: 2, default: "1.35"
    t.date "effective_from"
    t.date "effective_until"
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["grade_level_id"], name: "index_grade_salary_tables_on_grade_level_id"
    t.index ["tenant_id", "grade_code", "effective_from"], name: "idx_grade_salary_tables_unique"
    t.index ["tenant_id"], name: "index_grade_salary_tables_on_tenant_id"
  end

  create_table "import_batches", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "source_file_name", null: false
    t.string "source_digest"
    t.datetime "imported_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "source_digest"], name: "index_import_batches_on_tenant_id_and_source_digest", unique: true
    t.index ["tenant_id"], name: "index_import_batches_on_tenant_id"
  end

  create_table "insurance_rate_tables", force: :cascade do |t|
    t.bigint "tenant_id"
    t.integer "year", null: false
    t.string "prefecture"
    t.decimal "health_insurance_rate", precision: 5, scale: 3
    t.decimal "nursing_insurance_rate", precision: 5, scale: 3
    t.decimal "pension_rate", precision: 5, scale: 3
    t.decimal "employment_insurance_rate", precision: 5, scale: 3
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_insurance_rate_tables_on_tenant_id"
    t.index ["year", "prefecture"], name: "idx_insurance_rate_tables_year_pref"
  end

  create_table "item_orders", force: :cascade do |t|
    t.bigint "period_id", null: false
    t.string "location"
    t.bigint "item_id", null: false
    t.integer "row_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["item_id"], name: "index_item_orders_on_item_id"
    t.index ["period_id", "location", "item_id"], name: "idx_item_orders_period_location_item", unique: true
    t.index ["period_id", "location", "row_index"], name: "idx_item_orders_period_location_row", unique: true
    t.index ["period_id"], name: "index_item_orders_on_period_id"
    t.index ["tenant_id"], name: "index_item_orders_on_tenant_id"
  end

  create_table "items", force: :cascade do |t|
    t.string "name", null: false
    t.string "category"
    t.integer "position"
    t.integer "row_index"
    t.boolean "above_basic", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.string "payroll_group"
    t.integer "payroll_group_position"
    t.boolean "hidden", default: false, null: false
    t.index ["name"], name: "index_items_on_name"
    t.index ["payroll_group"], name: "index_items_on_payroll_group"
    t.index ["tenant_id", "name", "above_basic"], name: "index_items_on_tenant_name_above_basic", unique: true
    t.index ["tenant_id"], name: "index_items_on_tenant_id"
  end

  create_table "job_categories", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_job_categories_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_job_categories_on_tenant_id"
  end

  create_table "job_positions", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.integer "grade"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_job_positions_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_job_positions_on_tenant_id"
  end

  create_table "journal_entries", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "import_batch_id", null: false
    t.date "entry_date", null: false
    t.string "slip_no"
    t.string "document_type"
    t.string "source_sheet_name"
    t.integer "source_start_row"
    t.integer "source_end_row"
    t.string "summary"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["import_batch_id"], name: "index_journal_entries_on_import_batch_id"
    t.index ["tenant_id", "entry_date"], name: "index_journal_entries_on_tenant_id_and_entry_date"
    t.index ["tenant_id", "slip_no"], name: "index_journal_entries_on_tenant_id_and_slip_no"
    t.index ["tenant_id"], name: "index_journal_entries_on_tenant_id"
  end

  create_table "journal_lines", force: :cascade do |t|
    t.bigint "journal_entry_id", null: false
    t.string "side", null: false
    t.string "account_code"
    t.string "account_name", null: false
    t.string "sub_account_name"
    t.string "dept_code"
    t.string "dept_name"
    t.string "vendor_name"
    t.bigint "amount", null: false
    t.decimal "tax_amount", precision: 15, scale: 2
    t.string "tax_category"
    t.string "tax_calculation"
    t.string "memo"
    t.integer "source_row_number"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["journal_entry_id", "account_name"], name: "index_journal_lines_on_journal_entry_id_and_account_name"
    t.index ["journal_entry_id", "side"], name: "index_journal_lines_on_journal_entry_id_and_side"
    t.index ["journal_entry_id"], name: "index_journal_lines_on_journal_entry_id"
  end

  create_table "knowledge_articles", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "author_id"
    t.string "title", null: false
    t.string "slug"
    t.text "body"
    t.string "category", default: "manual"
    t.string "tags"
    t.boolean "published", default: false
    t.datetime "published_at"
    t.integer "view_count", default: 0
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_knowledge_articles_on_author_id"
    t.index ["tenant_id", "category"], name: "index_knowledge_articles_on_tenant_id_and_category"
    t.index ["tenant_id", "published"], name: "index_knowledge_articles_on_tenant_id_and_published"
    t.index ["tenant_id", "slug"], name: "index_knowledge_articles_on_tenant_id_and_slug", unique: true
    t.index ["tenant_id"], name: "index_knowledge_articles_on_tenant_id"
  end

  create_table "maintenance_categories", force: :cascade do |t|
    t.string "key", null: false
    t.string "name", null: false
    t.string "color"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_maintenance_categories_on_key", unique: true
  end

  create_table "maintenance_events", force: :cascade do |t|
    t.string "vehicle_number", null: false
    t.string "category", null: false
    t.datetime "start_at", null: false
    t.datetime "end_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "status", default: "scheduled", null: false
    t.text "notes"
    t.string "repair_location"
    t.string "vendor_name"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.index ["category"], name: "index_maintenance_events_on_category"
    t.index ["start_at"], name: "index_maintenance_events_on_start_at"
    t.index ["vehicle_number"], name: "index_maintenance_events_on_vehicle_number"
  end

  create_table "metric_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "display_label"
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_metric_categories_on_position"
  end

  create_table "metric_category_items", force: :cascade do |t|
    t.bigint "metric_category_id", null: false
    t.string "display_label", null: false
    t.text "source_labels", default: "", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_category_id", "position"], name: "index_metric_category_items_on_category_and_position"
    t.index ["metric_category_id"], name: "index_metric_category_items_on_metric_category_id"
  end

  create_table "orders", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "client_id"
    t.bigint "pickup_location_id"
    t.bigint "delivery_location_id"
    t.bigint "created_by_id"
    t.date "order_date", null: false
    t.date "delivery_date", null: false
    t.string "delivery_time"
    t.string "pickup_reservation_time"
    t.string "cargo_type"
    t.decimal "quantity", precision: 10, scale: 2
    t.string "unit", default: "t"
    t.string "concentration"
    t.string "required_vehicle_type"
    t.string "tank_designation"
    t.string "client_order_no"
    t.integer "source", default: 0
    t.integer "status", default: 0
    t.integer "estimated_duration_min"
    t.decimal "estimated_distance_km", precision: 8, scale: 2
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_orders_on_client_id"
    t.index ["created_by_id"], name: "index_orders_on_created_by_id"
    t.index ["delivery_location_id"], name: "index_orders_on_delivery_location_id"
    t.index ["pickup_location_id"], name: "index_orders_on_pickup_location_id"
    t.index ["tenant_id", "client_id"], name: "index_orders_on_tenant_id_and_client_id"
    t.index ["tenant_id", "client_order_no"], name: "index_orders_on_tenant_id_and_client_order_no"
    t.index ["tenant_id", "delivery_date"], name: "index_orders_on_tenant_id_and_delivery_date"
    t.index ["tenant_id", "status"], name: "index_orders_on_tenant_id_and_status"
    t.index ["tenant_id"], name: "index_orders_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.index ["period_id", "location"], name: "idx_payroll_batches_period_location"
    t.index ["period_id"], name: "index_payroll_batches_on_period_id"
    t.index ["tenant_id"], name: "index_payroll_batches_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.index ["employee_id"], name: "index_payroll_cells_on_employee_id"
    t.index ["item_id"], name: "index_payroll_cells_on_item_id"
    t.index ["payroll_batch_id"], name: "index_payroll_cells_on_payroll_batch_id"
    t.index ["period_id", "location", "employee_id", "item_id"], name: "idx_payroll_cells_unique", unique: true
    t.index ["period_id"], name: "index_payroll_cells_on_period_id"
    t.index ["tenant_id"], name: "index_payroll_cells_on_tenant_id"
  end

  create_table "payroll_column_orders", force: :cascade do |t|
    t.bigint "period_id", null: false
    t.string "location"
    t.bigint "employee_id", null: false
    t.integer "column_index", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["employee_id"], name: "index_payroll_column_orders_on_employee_id"
    t.index ["period_id", "location", "column_index"], name: "idx_payroll_column_orders_period_col", unique: true
    t.index ["period_id", "location", "employee_id"], name: "idx_payroll_column_orders_unique", unique: true
    t.index ["period_id"], name: "index_payroll_column_orders_on_period_id"
    t.index ["tenant_id"], name: "index_payroll_column_orders_on_tenant_id"
  end

  create_table "periods", force: :cascade do |t|
    t.integer "year", null: false
    t.integer "month", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["tenant_id", "year", "month"], name: "index_periods_on_tenant_year_month", unique: true
    t.index ["tenant_id"], name: "index_periods_on_tenant_id"
  end

  create_table "pl_mappings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "pl_tree_node_id", null: false
    t.integer "priority", default: 100, null: false
    t.string "mapping_scope", default: "company", null: false
    t.string "account_code"
    t.string "account_name"
    t.string "vendor_name"
    t.string "memo_keyword"
    t.string "dept_code"
    t.string "vehicle_id"
    t.boolean "active", default: true, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pl_tree_node_id"], name: "index_pl_mappings_on_pl_tree_node_id"
    t.index ["tenant_id", "account_code"], name: "index_pl_mappings_on_tenant_id_and_account_code"
    t.index ["tenant_id", "priority"], name: "index_pl_mappings_on_tenant_id_and_priority"
    t.index ["tenant_id", "vendor_name"], name: "index_pl_mappings_on_tenant_id_and_vendor_name"
    t.index ["tenant_id"], name: "index_pl_mappings_on_tenant_id"
  end

  create_table "pl_tree_nodes", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.bigint "parent_id"
    t.integer "display_order", default: 0, null: false
    t.integer "depth", default: 0, null: false
    t.string "node_type", default: "normal", null: false
    t.text "expression"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_pl_tree_nodes_on_tenant_id_and_code", unique: true
    t.index ["tenant_id", "parent_id", "display_order"], name: "index_pl_tree_nodes_on_tenant_and_parent_and_order"
    t.index ["tenant_id"], name: "index_pl_tree_nodes_on_tenant_id"
  end

  create_table "route_distances", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "origin_code", null: false
    t.string "destination_code", null: false
    t.decimal "distance_km", precision: 8, scale: 2
    t.integer "duration_minutes"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "origin_code", "destination_code"], name: "idx_route_distances_unique", unique: true
    t.index ["tenant_id"], name: "index_route_distances_on_tenant_id"
  end

  create_table "salary_draft_decisions", force: :cascade do |t|
    t.bigint "employee_id", null: false
    t.bigint "period_id", null: false
    t.integer "selected_grade"
    t.string "selected_safety"
    t.string "selected_difficulty"
    t.integer "position_allowance", default: 0
    t.integer "role_allowance", default: 0
    t.decimal "overtime_hours", precision: 5, scale: 1, default: "0.0"
    t.decimal "late_night_hours", precision: 5, scale: 1, default: "0.0"
    t.decimal "holiday_hours", precision: 5, scale: 1, default: "0.0"
    t.integer "current_fixed_total", default: 0
    t.integer "current_gross_total", default: 0
    t.integer "current_net_total", default: 0
    t.integer "current_company_cost", default: 0
    t.integer "proposed_fixed_total", default: 0
    t.integer "proposed_gross_total", default: 0
    t.integer "proposed_net_total", default: 0
    t.integer "proposed_company_cost", default: 0
    t.integer "diff_fixed", default: 0
    t.integer "diff_gross", default: 0
    t.integer "diff_net", default: 0
    t.integer "diff_company_cost", default: 0
    t.string "location"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id", "period_id"], name: "index_salary_draft_decisions_on_employee_id_and_period_id", unique: true
    t.index ["employee_id"], name: "index_salary_draft_decisions_on_employee_id"
    t.index ["period_id"], name: "index_salary_draft_decisions_on_period_id"
  end

  create_table "salary_monthlies", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "employee_id"
    t.string "employee_code", null: false
    t.string "employee_name"
    t.string "location"
    t.integer "year", null: false
    t.integer "month", null: false
    t.string "payment_type", default: "regular"
    t.decimal "working_days", precision: 5, scale: 2
    t.decimal "paid_leave_days", precision: 5, scale: 2
    t.decimal "working_hours", precision: 8, scale: 2
    t.decimal "paid_leave_hours", precision: 10, scale: 2
    t.decimal "paid_leave_remaining", precision: 5, scale: 2
    t.integer "basic_salary"
    t.integer "city_allowance"
    t.integer "basic_salary_2"
    t.integer "executive_salary"
    t.integer "paid_leave_pay"
    t.integer "taxable_total"
    t.integer "commuting_allowance"
    t.integer "nontaxable_total"
    t.integer "gross_total"
    t.integer "health_insurance"
    t.integer "nursing_insurance"
    t.integer "pension_insurance"
    t.integer "employment_insurance"
    t.integer "social_insurance_adjustment"
    t.integer "social_insurance_total"
    t.integer "income_tax"
    t.integer "resident_tax"
    t.integer "deduction_total"
    t.integer "taxable_income"
    t.integer "net_total"
    t.integer "cash_payment"
    t.integer "bank_transfer"
    t.integer "dependents_count"
    t.string "tax_table"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "safety_bonus"
    t.integer "weekday_overtime_pay"
    t.integer "statutory_holiday_pay"
    t.integer "non_statutory_holiday_pay"
    t.integer "substitute_holiday_pay"
    t.integer "premium_overtime_pay"
    t.integer "late_night_pay"
    t.integer "regular_overtime_pay"
    t.integer "union_fee"
    t.decimal "statutory_holiday_days", precision: 5, scale: 2
    t.decimal "non_statutory_holiday_days", precision: 5, scale: 2
    t.decimal "absence_days", precision: 5, scale: 2
    t.decimal "statutory_holiday_hours", precision: 10, scale: 2
    t.decimal "non_statutory_holiday_hours", precision: 10, scale: 2
    t.integer "position_allowance", default: 0
    t.integer "role_allowance", default: 0
    t.integer "adjustment_salary", default: 0
    t.integer "adjustment_allowance", default: 0
    t.integer "absence_deduction", default: 0
    t.index ["employee_id"], name: "index_salary_monthlies_on_employee_id"
    t.index ["tenant_id", "employee_code", "year", "month", "payment_type"], name: "idx_salary_monthly_tenant_emp_ym_type", unique: true
    t.index ["tenant_id", "location"], name: "index_salary_monthlies_on_tenant_id_and_location"
    t.index ["tenant_id", "year", "month"], name: "index_salary_monthlies_on_tenant_id_and_year_and_month"
    t.index ["tenant_id"], name: "index_salary_monthlies_on_tenant_id"
  end

  create_table "salary_scenario_items", force: :cascade do |t|
    t.bigint "salary_scenario_id", null: false
    t.string "name", null: false
    t.string "category"
    t.string "calculation_type", default: "fixed"
    t.integer "default_amount", default: 0
    t.string "formula"
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["salary_scenario_id"], name: "index_salary_scenario_items_on_salary_scenario_id"
  end

  create_table "salary_scenario_results", force: :cascade do |t|
    t.bigint "salary_scenario_id", null: false
    t.bigint "employee_id", null: false
    t.bigint "period_id"
    t.integer "base_salary", default: 0
    t.integer "total_allowances", default: 0
    t.integer "overtime_pay", default: 0
    t.integer "late_night_pay", default: 0
    t.integer "holiday_pay", default: 0
    t.integer "gross_pay", default: 0
    t.integer "deductions", default: 0
    t.integer "net_pay", default: 0
    t.jsonb "calculation_details", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["employee_id"], name: "index_salary_scenario_results_on_employee_id"
    t.index ["period_id"], name: "index_salary_scenario_results_on_period_id"
    t.index ["salary_scenario_id", "employee_id"], name: "idx_scenario_employee", unique: true
    t.index ["salary_scenario_id"], name: "index_salary_scenario_results_on_salary_scenario_id"
  end

  create_table "salary_scenarios", force: :cascade do |t|
    t.bigint "tenant_id"
    t.string "name", null: false
    t.text "description"
    t.jsonb "parameters", default: {}
    t.boolean "is_baseline", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_salary_scenarios_on_tenant_id"
  end

  create_table "salary_settings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "employee_id", null: false
    t.string "salary_type", default: "monthly"
    t.bigint "grade_salary_table_id"
    t.integer "base_salary_override"
    t.integer "commuting_allowance", default: 0
    t.integer "family_allowance", default: 0
    t.integer "housing_allowance", default: 0
    t.integer "position_allowance", default: 0
    t.integer "qualification_allowance", default: 0
    t.integer "resident_tax", default: 0
    t.integer "dependents_count", default: 0
    t.string "tax_table_type", default: "甲"
    t.date "effective_from", null: false
    t.date "effective_until"
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "hourly_rate_override"
    t.integer "safety_bonus"
    t.integer "commuting_daily_rate"
    t.decimal "commuting_distance", precision: 6, scale: 2
    t.decimal "fuel_efficiency", precision: 4, scale: 1, default: "13.0"
    t.string "commuting_type", default: "car"
    t.integer "safety_bonus_cumulative", default: 0
    t.integer "adjustment_salary", default: 0
    t.integer "adjustment_allowance", default: 0
    t.integer "basic_salary_2", default: 0
    t.integer "executive_salary", default: 0
    t.integer "role_allowance", default: 0
    t.integer "absence_deduction", default: 0
    t.integer "union_fee", default: 0
    t.integer "standard_monthly_remuneration"
    t.boolean "nursing_insurance_flag"
    t.index ["employee_id"], name: "index_salary_settings_on_employee_id"
    t.index ["grade_salary_table_id"], name: "index_salary_settings_on_grade_salary_table_id"
    t.index ["tenant_id", "employee_id", "effective_from"], name: "idx_salary_settings_unique", unique: true
    t.index ["tenant_id"], name: "index_salary_settings_on_tenant_id"
  end

  create_table "salary_simulations", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "employee_id"
    t.string "employee_code", null: false
    t.integer "year", null: false
    t.integer "month", null: false
    t.bigint "attendance_monthly_id"
    t.bigint "salary_setting_id"
    t.decimal "working_days", precision: 5, scale: 2
    t.decimal "overtime_hours", precision: 6, scale: 2
    t.decimal "late_night_hours", precision: 6, scale: 2
    t.decimal "holiday_hours", precision: 6, scale: 2
    t.decimal "paid_leave_days", precision: 5, scale: 2
    t.integer "calc_basic_salary", default: 0
    t.integer "calc_overtime_pay", default: 0
    t.integer "calc_late_night_pay", default: 0
    t.integer "calc_holiday_pay", default: 0
    t.integer "calc_paid_leave_pay", default: 0
    t.integer "calc_commuting_allowance", default: 0
    t.integer "calc_other_allowances", default: 0
    t.integer "calc_gross_total", default: 0
    t.integer "calc_health_insurance", default: 0
    t.integer "calc_nursing_insurance", default: 0
    t.integer "calc_pension", default: 0
    t.integer "calc_employment_insurance", default: 0
    t.integer "calc_income_tax", default: 0
    t.integer "calc_resident_tax", default: 0
    t.integer "calc_deduction_total", default: 0
    t.integer "calc_net_total", default: 0
    t.integer "actual_gross_total"
    t.integer "actual_net_total"
    t.integer "diff_gross"
    t.integer "diff_net"
    t.string "status", default: "draft"
    t.text "notes"
    t.jsonb "calculation_details", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "calc_safety_bonus"
    t.integer "calc_union_fee"
    t.datetime "approved_at"
    t.bigint "approved_by_id"
    t.text "approval_note"
    t.integer "calc_substitute_holiday_pay", default: 0
    t.index ["approved_by_id"], name: "index_salary_simulations_on_approved_by_id"
    t.index ["attendance_monthly_id"], name: "index_salary_simulations_on_attendance_monthly_id"
    t.index ["employee_id"], name: "index_salary_simulations_on_employee_id"
    t.index ["salary_setting_id"], name: "index_salary_simulations_on_salary_setting_id"
    t.index ["tenant_id", "employee_code", "year", "month"], name: "idx_salary_simulations_unique", unique: true
    t.index ["tenant_id"], name: "index_salary_simulations_on_tenant_id"
  end

  create_table "shippers", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "postal_code"
    t.string "address"
    t.string "phone"
    t.string "fax"
    t.string "contact_name"
    t.string "billing_closing_day"
    t.string "payment_terms"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_shippers_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_shippers_on_tenant_id"
  end

  create_table "snapshots", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "pl_tree_node_id", null: false
    t.date "period_month", null: false
    t.string "scope_type", null: false
    t.string "scope_key", default: "company", null: false
    t.bigint "actual_amount", default: 0, null: false
    t.bigint "managed_amount", default: 0, null: false
    t.bigint "fixed_amount", default: 0, null: false
    t.bigint "variable_amount", default: 0, null: false
    t.bigint "unknown_amount", default: 0, null: false
    t.datetime "generated_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pl_tree_node_id"], name: "index_snapshots_on_pl_tree_node_id"
    t.index ["tenant_id", "period_month", "scope_type", "scope_key", "pl_tree_node_id"], name: "index_snapshots_on_scope_and_node", unique: true
    t.index ["tenant_id"], name: "index_snapshots_on_tenant_id"
  end

  create_table "subcontractor_companies", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "code", null: false
    t.string "name", null: false
    t.string "postal_code"
    t.string "address"
    t.string "phone"
    t.string "fax"
    t.string "contact_name"
    t.string "rate_category"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "code"], name: "index_subcontractor_companies_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_subcontractor_companies_on_tenant_id"
  end

  create_table "summary_settings", force: :cascade do |t|
    t.integer "term_start_month", default: 9, null: false
    t.jsonb "label_mappings", default: {}, null: false
    t.bigint "tenant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "fiscal_year_origin"
    t.index ["tenant_id"], name: "index_summary_settings_on_tenant_id"
  end

  create_table "tariffs", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "shipper_id"
    t.string "code", null: false
    t.string "origin"
    t.string "destination"
    t.string "vehicle_class"
    t.string "weight_category"
    t.integer "unit_price"
    t.date "effective_from"
    t.date "effective_until"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["shipper_id"], name: "index_tariffs_on_shipper_id"
    t.index ["tenant_id", "code"], name: "index_tariffs_on_tenant_id_and_code", unique: true
    t.index ["tenant_id"], name: "index_tariffs_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "time_zone"
    t.jsonb "settings", default: {}, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "fuel_price", precision: 5, scale: 1, default: "160.0"
    t.date "fuel_price_updated_at"
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
  end

  create_table "transport_orders", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "order_no"
    t.date "order_date", null: false
    t.bigint "vehicle_id"
    t.bigint "employee_id"
    t.bigint "department_id"
    t.bigint "shipper_id"
    t.date "loading_date"
    t.time "loading_time"
    t.date "departure_date"
    t.time "departure_time"
    t.date "arrival_date"
    t.time "arrival_time"
    t.bigint "origin_location_id"
    t.bigint "destination_location_id"
    t.decimal "quantity", precision: 10, scale: 2
    t.string "unit"
    t.decimal "weight", precision: 10, scale: 2
    t.decimal "distance_km", precision: 10, scale: 2
    t.decimal "driving_km", precision: 10, scale: 2
    t.decimal "billing_unit_price", precision: 10, scale: 2
    t.integer "billing_base_amount", default: 0
    t.integer "billing_surcharge", default: 0
    t.integer "billing_toll", default: 0
    t.integer "billing_other", default: 0
    t.integer "billing_tax", default: 0
    t.integer "billing_total", default: 0
    t.date "billing_date"
    t.date "billing_closing_date"
    t.decimal "payment_unit_price", precision: 10, scale: 2
    t.integer "payment_base_amount", default: 0
    t.integer "payment_toll", default: 0
    t.integer "payment_tax", default: 0
    t.integer "vehicle_amount", default: 0
    t.integer "driver_amount", default: 0
    t.text "remarks"
    t.integer "status", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["department_id"], name: "index_transport_orders_on_department_id"
    t.index ["destination_location_id"], name: "index_transport_orders_on_destination_location_id"
    t.index ["employee_id"], name: "index_transport_orders_on_employee_id"
    t.index ["origin_location_id"], name: "index_transport_orders_on_origin_location_id"
    t.index ["shipper_id"], name: "index_transport_orders_on_shipper_id"
    t.index ["tenant_id", "billing_date"], name: "index_transport_orders_on_tenant_id_and_billing_date"
    t.index ["tenant_id", "order_date"], name: "index_transport_orders_on_tenant_id_and_order_date"
    t.index ["tenant_id", "order_no"], name: "index_transport_orders_on_tenant_id_and_order_no", unique: true
    t.index ["tenant_id"], name: "index_transport_orders_on_tenant_id"
    t.index ["vehicle_id"], name: "index_transport_orders_on_vehicle_id"
  end

  create_table "unmapped_vehicle_numbers", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "raw_number", null: false
    t.string "cleaned_number"
    t.integer "occurrence_count", default: 1, null: false
    t.datetime "first_seen_at", null: false
    t.datetime "last_seen_at", null: false
    t.boolean "resolved", default: false, null: false
    t.string "resolved_to"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "raw_number"], name: "idx_unmapped_vehicle_numbers_unique", unique: true
    t.index ["tenant_id"], name: "index_unmapped_vehicle_numbers_on_tenant_id"
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
    t.bigint "tenant_id", null: false
    t.bigint "employment_id", null: false
    t.index ["employment_id"], name: "index_users_on_employment_id", unique: true, where: "(employment_id IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["tenant_id", "email"], name: "index_users_on_tenant_and_email", unique: true
    t.index ["tenant_id"], name: "index_users_on_tenant_id"
  end

  create_table "vehicle_aliases", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "pattern", null: false
    t.string "pattern_type", default: "exact", null: false
    t.string "vehicle_id", null: false
    t.boolean "active", default: true, null: false
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "pattern"], name: "index_vehicle_aliases_on_tenant_id_and_pattern", unique: true
    t.index ["tenant_id", "vehicle_id"], name: "index_vehicle_aliases_on_tenant_id_and_vehicle_id"
    t.index ["tenant_id"], name: "index_vehicle_aliases_on_tenant_id"
  end

  create_table "vehicle_cargo_bindings", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.string "cargo_name", null: false
    t.string "cargo_category"
    t.bigint "shipper_id"
    t.bigint "default_origin_id"
    t.bigint "default_destination_id"
    t.boolean "is_default", default: true, null: false
    t.integer "priority", default: 0, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["default_destination_id"], name: "index_vehicle_cargo_bindings_on_default_destination_id"
    t.index ["default_origin_id"], name: "index_vehicle_cargo_bindings_on_default_origin_id"
    t.index ["shipper_id"], name: "index_vehicle_cargo_bindings_on_shipper_id"
    t.index ["tenant_id", "cargo_category"], name: "index_vehicle_cargo_bindings_on_tenant_id_and_cargo_category"
    t.index ["tenant_id", "vehicle_id"], name: "index_vehicle_cargo_bindings_on_tenant_id_and_vehicle_id"
    t.index ["tenant_id"], name: "index_vehicle_cargo_bindings_on_tenant_id"
    t.index ["vehicle_id"], name: "index_vehicle_cargo_bindings_on_vehicle_id"
  end

  create_table "vehicle_daily_statuses", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.bigint "plan_driver_id"
    t.date "date", null: false
    t.integer "status", default: 0
    t.string "reason"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["plan_driver_id"], name: "index_vehicle_daily_statuses_on_plan_driver_id"
    t.index ["tenant_id", "date", "status"], name: "idx_vehicle_daily_status_date"
    t.index ["tenant_id", "vehicle_id", "date"], name: "idx_vehicle_daily_status_unique", unique: true
    t.index ["tenant_id"], name: "index_vehicle_daily_statuses_on_tenant_id"
    t.index ["vehicle_id"], name: "index_vehicle_daily_statuses_on_vehicle_id"
  end

  create_table "vehicle_fault_logs", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.string "title", null: false
    t.date "occurred_on"
    t.date "resolved_on"
    t.string "status", default: "on_hold", null: false
    t.string "severity", default: "medium", null: false
    t.string "category"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cause_primary"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.index ["tenant_id", "vehicle_id", "occurred_on"], name: "index_fault_logs_on_tenant_vehicle_date"
    t.index ["tenant_id"], name: "index_vehicle_fault_logs_on_tenant_id"
    t.index ["vehicle_id"], name: "index_vehicle_fault_logs_on_vehicle_id"
  end

  create_table "vehicle_faults", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.date "started_on", null: false
    t.date "resolved_on"
    t.string "summary", null: false
    t.text "details"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "vehicle_id", "started_on"], name: "index_vehicle_faults_on_tenant_vehicle_started"
    t.index ["tenant_id"], name: "index_vehicle_faults_on_tenant_id"
    t.index ["vehicle_id"], name: "index_vehicle_faults_on_vehicle_id"
  end

  create_table "vehicle_financial_metrics", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id"
    t.string "vehicle_code", null: false
    t.date "month", null: false
    t.string "metric_key", null: false
    t.string "metric_label", null: false
    t.decimal "value_numeric", precision: 18, scale: 2
    t.string "value_text"
    t.string "unit"
    t.string "source_file"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "cell_state", default: "value", null: false
    t.index ["tenant_id", "month"], name: "index_vehicle_financial_metrics_on_tenant_id_and_month"
    t.index ["tenant_id", "vehicle_code", "month", "metric_key"], name: "index_vehicle_financial_metrics_dedup"
    t.index ["tenant_id"], name: "index_vehicle_financial_metrics_on_tenant_id"
    t.index ["vehicle_id"], name: "index_vehicle_financial_metrics_on_vehicle_id"
  end

  create_table "vehicle_groups", force: :cascade do |t|
    t.bigint "tenant_id"
    t.string "name", null: false
    t.string "group_type", default: "custom"
    t.jsonb "vehicle_codes", default: []
    t.jsonb "code_mappings", default: {}
    t.integer "position", default: 0
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "group_type"], name: "index_vehicle_groups_on_tenant_id_and_group_type"
    t.index ["tenant_id", "name"], name: "index_vehicle_groups_on_tenant_id_and_name", unique: true
    t.index ["tenant_id"], name: "index_vehicle_groups_on_tenant_id"
  end

  create_table "vehicle_inspection_records", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.string "inspection_type", null: false
    t.date "scheduled_on"
    t.date "completed_on"
    t.string "status", default: "scheduled", null: false
    t.string "inspector_name"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "inspection_scope"
    t.string "vendor_name"
    t.decimal "estimated_cost", precision: 12, scale: 2
    t.index ["tenant_id", "vehicle_id", "scheduled_on"], name: "index_inspections_on_tenant_vehicle_scheduled"
    t.index ["tenant_id"], name: "index_vehicle_inspection_records_on_tenant_id"
    t.index ["vehicle_id"], name: "index_vehicle_inspection_records_on_vehicle_id"
  end

  create_table "vehicle_statuses", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.bigint "vehicle_id", null: false
    t.string "status", null: false
    t.string "source_type"
    t.bigint "source_id"
    t.date "effective_on"
    t.string "notes"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type", "source_id"], name: "index_vehicle_statuses_on_source_type_and_source_id"
    t.index ["tenant_id"], name: "index_vehicle_statuses_on_tenant_id"
    t.index ["vehicle_id"], name: "index_vehicle_statuses_on_vehicle_id"
  end

  create_table "vehicles", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "depot_name"
    t.string "registration_number", null: false
    t.string "call_sign"
    t.date "first_registration_on"
    t.string "age_text"
    t.string "model_code"
    t.string "manufacturer_name"
    t.string "chassis_number"
    t.string "vehicle_category"
    t.integer "max_load_kg"
    t.integer "gross_weight_kg"
    t.string "chassis_base"
    t.string "pto"
    t.string "shipper_name"
    t.string "cargo_name"
    t.string "specific_gravity"
    t.date "tank_made_on"
    t.string "tank_age_text"
    t.string "hatch_pattern"
    t.string "tank_material"
    t.string "tank_manufacturer"
    t.integer "tire_count"
    t.string "body_type"
    t.string "usage_category"
    t.text "notes"
    t.jsonb "metadata", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "fault_status", default: 0, null: false
    t.bigint "default_employee_id"
    t.string "vehicle_group"
    t.index ["tenant_id", "registration_number", "first_registration_on"], name: "idx_vehicles_unique_registration", unique: true
    t.index ["tenant_id"], name: "index_vehicles_on_tenant_id"
  end

  create_table "workflow_approvals", force: :cascade do |t|
    t.bigint "workflow_stage_id", null: false
    t.bigint "actor_id", null: false
    t.string "action", null: false
    t.text "comment"
    t.datetime "acted_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["actor_id"], name: "index_workflow_approvals_on_actor_id"
    t.index ["tenant_id"], name: "index_workflow_approvals_on_tenant_id"
    t.index ["workflow_stage_id"], name: "index_workflow_approvals_on_stage_id"
  end

  create_table "workflow_categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "code", null: false
    t.text "description"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["tenant_id", "code"], name: "index_workflow_categories_on_tenant_and_code", unique: true
    t.index ["tenant_id"], name: "index_workflow_categories_on_tenant_id"
  end

  create_table "workflow_category_notifications", force: :cascade do |t|
    t.bigint "workflow_category_id", null: false
    t.string "role", null: false
    t.string "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["tenant_id"], name: "index_workflow_category_notifications_on_tenant_id"
    t.index ["workflow_category_id"], name: "index_category_notifications_on_category"
  end

  create_table "workflow_notes", force: :cascade do |t|
    t.bigint "workflow_request_id", null: false
    t.bigint "author_id", null: false
    t.text "body", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["author_id"], name: "index_workflow_notes_on_author_id"
    t.index ["tenant_id"], name: "index_workflow_notes_on_tenant_id"
    t.index ["workflow_request_id"], name: "index_workflow_notes_on_workflow_request_id"
  end

  create_table "workflow_requests", force: :cascade do |t|
    t.bigint "workflow_category_id", null: false
    t.bigint "requester_id", null: false
    t.string "title", null: false
    t.string "status", default: "draft", null: false
    t.decimal "amount", precision: 15, scale: 2
    t.string "currency", default: "JPY", null: false
    t.string "vendor_name"
    t.string "vehicle_identifier"
    t.date "needed_on"
    t.text "summary"
    t.text "additional_information"
    t.datetime "submitted_at"
    t.datetime "finalized_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.jsonb "metadata", default: {}, null: false
    t.bigint "requester_employee_id"
    t.bigint "tenant_id", null: false
    t.index ["requester_employee_id"], name: "index_workflow_requests_on_requester_employee_id"
    t.index ["requester_id"], name: "index_workflow_requests_on_requester_id"
    t.index ["status"], name: "index_workflow_requests_on_status"
    t.index ["submitted_at"], name: "index_workflow_requests_on_submitted_at"
    t.index ["tenant_id"], name: "index_workflow_requests_on_tenant_id"
    t.index ["workflow_category_id"], name: "index_workflow_requests_on_category_id"
  end

  create_table "workflow_stage_templates", force: :cascade do |t|
    t.bigint "workflow_category_id", null: false
    t.integer "position", default: 1, null: false
    t.string "name", null: false
    t.string "responsible_role"
    t.bigint "responsible_user_id"
    t.string "instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["responsible_user_id"], name: "index_workflow_stage_templates_on_responsible_user_id"
    t.index ["tenant_id"], name: "index_workflow_stage_templates_on_tenant_id"
    t.index ["workflow_category_id", "position"], name: "index_stage_templates_on_category_and_position"
    t.index ["workflow_category_id"], name: "index_stage_templates_on_category_id"
  end

  create_table "workflow_stages", force: :cascade do |t|
    t.bigint "workflow_request_id", null: false
    t.integer "position", default: 1, null: false
    t.string "name", null: false
    t.string "status", default: "pending", null: false
    t.string "responsible_role"
    t.bigint "responsible_user_id"
    t.datetime "activated_at"
    t.datetime "completed_at"
    t.text "last_comment"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "tenant_id", null: false
    t.index ["responsible_user_id"], name: "index_workflow_stages_on_responsible_user_id"
    t.index ["status"], name: "index_workflow_stages_on_status"
    t.index ["tenant_id"], name: "index_workflow_stages_on_tenant_id"
    t.index ["workflow_request_id", "position"], name: "index_workflow_stages_on_request_and_position"
    t.index ["workflow_request_id"], name: "index_workflow_stages_on_request_id"
  end

  add_foreign_key "announcements", "tenants"
  add_foreign_key "announcements", "users", column: "author_id"
  add_foreign_key "attendance_monthlies", "employees"
  add_foreign_key "attendance_monthlies", "tenants"
  add_foreign_key "attendance_records", "employees"
  add_foreign_key "attendance_records", "tenants"
  add_foreign_key "bookmarks", "tenants"
  add_foreign_key "bookmarks", "users", column: "creator_id"
  add_foreign_key "classification_rules", "tenants"
  add_foreign_key "client_driver_policies", "employees", column: "driver_id"
  add_foreign_key "client_driver_policies", "shippers", column: "client_id"
  add_foreign_key "client_driver_policies", "tenants"
  add_foreign_key "departments", "tenants"
  add_foreign_key "destinations", "shippers"
  add_foreign_key "destinations", "tenants"
  add_foreign_key "dispatch_assignments", "destinations", column: "destination_location_id"
  add_foreign_key "dispatch_assignments", "destinations", column: "origin_location_id"
  add_foreign_key "dispatch_assignments", "dispatch_plans"
  add_foreign_key "dispatch_assignments", "employees"
  add_foreign_key "dispatch_assignments", "orders"
  add_foreign_key "dispatch_assignments", "shippers"
  add_foreign_key "dispatch_assignments", "tenants"
  add_foreign_key "dispatch_assignments", "transport_orders"
  add_foreign_key "dispatch_assignments", "vehicles"
  add_foreign_key "dispatch_plans", "tenants"
  add_foreign_key "driver_daily_statuses", "employees", column: "driver_id"
  add_foreign_key "driver_daily_statuses", "shippers", column: "plan_client_id"
  add_foreign_key "driver_daily_statuses", "tenants"
  add_foreign_key "driver_daily_statuses", "vehicles", column: "actual_vehicle_id"
  add_foreign_key "driver_daily_statuses", "vehicles", column: "plan_vehicle_id"
  add_foreign_key "employee_assignments", "employees"
  add_foreign_key "employee_assignments", "tenants"
  add_foreign_key "employee_positions", "employees"
  add_foreign_key "employee_positions", "tenants"
  add_foreign_key "employee_qualifications", "employees"
  add_foreign_key "employee_qualifications", "tenants"
  add_foreign_key "employee_reviews", "employees"
  add_foreign_key "employee_reviews", "evaluation_cycles"
  add_foreign_key "employee_reviews", "evaluation_grades"
  add_foreign_key "employee_reviews", "grade_levels"
  add_foreign_key "employee_reviews", "tenants"
  add_foreign_key "employee_statuses", "employees"
  add_foreign_key "employee_statuses", "tenants"
  add_foreign_key "employees", "departments"
  add_foreign_key "employees", "grade_levels"
  add_foreign_key "employees", "job_categories"
  add_foreign_key "employees", "job_positions"
  add_foreign_key "employees", "tenants"
  add_foreign_key "evaluation_cycles", "tenants"
  add_foreign_key "evaluation_grades", "tenants"
  add_foreign_key "grade_levels", "tenants"
  add_foreign_key "grade_salary_tables", "grade_levels"
  add_foreign_key "grade_salary_tables", "tenants"
  add_foreign_key "import_batches", "tenants"
  add_foreign_key "insurance_rate_tables", "tenants"
  add_foreign_key "item_orders", "items"
  add_foreign_key "item_orders", "periods"
  add_foreign_key "item_orders", "tenants"
  add_foreign_key "items", "tenants"
  add_foreign_key "job_categories", "tenants"
  add_foreign_key "job_positions", "tenants"
  add_foreign_key "journal_entries", "import_batches"
  add_foreign_key "journal_entries", "tenants"
  add_foreign_key "journal_lines", "journal_entries"
  add_foreign_key "knowledge_articles", "tenants"
  add_foreign_key "knowledge_articles", "users", column: "author_id"
  add_foreign_key "metric_category_items", "metric_categories"
  add_foreign_key "orders", "destinations", column: "delivery_location_id"
  add_foreign_key "orders", "destinations", column: "pickup_location_id"
  add_foreign_key "orders", "shippers", column: "client_id"
  add_foreign_key "orders", "tenants"
  add_foreign_key "orders", "users", column: "created_by_id"
  add_foreign_key "payroll_batches", "periods"
  add_foreign_key "payroll_batches", "tenants"
  add_foreign_key "payroll_batches", "users", column: "uploaded_by_id"
  add_foreign_key "payroll_cells", "employees"
  add_foreign_key "payroll_cells", "items"
  add_foreign_key "payroll_cells", "payroll_batches"
  add_foreign_key "payroll_cells", "periods"
  add_foreign_key "payroll_cells", "tenants"
  add_foreign_key "payroll_column_orders", "employees"
  add_foreign_key "payroll_column_orders", "periods"
  add_foreign_key "payroll_column_orders", "tenants"
  add_foreign_key "periods", "tenants"
  add_foreign_key "pl_mappings", "pl_tree_nodes"
  add_foreign_key "pl_mappings", "tenants"
  add_foreign_key "pl_tree_nodes", "pl_tree_nodes", column: "parent_id"
  add_foreign_key "pl_tree_nodes", "tenants"
  add_foreign_key "route_distances", "tenants"
  add_foreign_key "salary_draft_decisions", "employees"
  add_foreign_key "salary_draft_decisions", "periods"
  add_foreign_key "salary_monthlies", "employees"
  add_foreign_key "salary_monthlies", "tenants"
  add_foreign_key "salary_scenario_items", "salary_scenarios"
  add_foreign_key "salary_scenario_results", "employees"
  add_foreign_key "salary_scenario_results", "periods"
  add_foreign_key "salary_scenario_results", "salary_scenarios"
  add_foreign_key "salary_scenarios", "tenants"
  add_foreign_key "salary_settings", "employees"
  add_foreign_key "salary_settings", "grade_salary_tables"
  add_foreign_key "salary_settings", "tenants"
  add_foreign_key "salary_simulations", "attendance_monthlies"
  add_foreign_key "salary_simulations", "employees"
  add_foreign_key "salary_simulations", "salary_settings"
  add_foreign_key "salary_simulations", "tenants"
  add_foreign_key "shippers", "tenants"
  add_foreign_key "snapshots", "pl_tree_nodes"
  add_foreign_key "snapshots", "tenants"
  add_foreign_key "subcontractor_companies", "tenants"
  add_foreign_key "summary_settings", "tenants"
  add_foreign_key "tariffs", "shippers"
  add_foreign_key "tariffs", "tenants"
  add_foreign_key "transport_orders", "departments"
  add_foreign_key "transport_orders", "destinations", column: "destination_location_id"
  add_foreign_key "transport_orders", "destinations", column: "origin_location_id"
  add_foreign_key "transport_orders", "employees"
  add_foreign_key "transport_orders", "shippers"
  add_foreign_key "transport_orders", "tenants"
  add_foreign_key "transport_orders", "vehicles"
  add_foreign_key "unmapped_vehicle_numbers", "tenants"
  add_foreign_key "users", "employees", column: "employment_id"
  add_foreign_key "users", "tenants"
  add_foreign_key "vehicle_aliases", "tenants"
  add_foreign_key "vehicle_cargo_bindings", "destinations", column: "default_destination_id"
  add_foreign_key "vehicle_cargo_bindings", "destinations", column: "default_origin_id"
  add_foreign_key "vehicle_cargo_bindings", "shippers"
  add_foreign_key "vehicle_cargo_bindings", "tenants"
  add_foreign_key "vehicle_cargo_bindings", "vehicles"
  add_foreign_key "vehicle_daily_statuses", "employees", column: "plan_driver_id"
  add_foreign_key "vehicle_daily_statuses", "tenants"
  add_foreign_key "vehicle_daily_statuses", "vehicles"
  add_foreign_key "vehicle_fault_logs", "tenants"
  add_foreign_key "vehicle_fault_logs", "vehicles"
  add_foreign_key "vehicle_faults", "tenants"
  add_foreign_key "vehicle_faults", "vehicles"
  add_foreign_key "vehicle_financial_metrics", "tenants"
  add_foreign_key "vehicle_financial_metrics", "vehicles"
  add_foreign_key "vehicle_groups", "tenants"
  add_foreign_key "vehicle_inspection_records", "tenants"
  add_foreign_key "vehicle_inspection_records", "vehicles"
  add_foreign_key "vehicle_statuses", "tenants"
  add_foreign_key "vehicle_statuses", "vehicles"
  add_foreign_key "vehicles", "tenants"
  add_foreign_key "workflow_approvals", "tenants"
  add_foreign_key "workflow_approvals", "users", column: "actor_id"
  add_foreign_key "workflow_approvals", "workflow_stages"
  add_foreign_key "workflow_categories", "tenants"
  add_foreign_key "workflow_category_notifications", "tenants"
  add_foreign_key "workflow_category_notifications", "workflow_categories"
  add_foreign_key "workflow_notes", "tenants"
  add_foreign_key "workflow_notes", "users", column: "author_id"
  add_foreign_key "workflow_notes", "workflow_requests"
  add_foreign_key "workflow_requests", "employees", column: "requester_employee_id"
  add_foreign_key "workflow_requests", "tenants"
  add_foreign_key "workflow_requests", "users", column: "requester_id"
  add_foreign_key "workflow_requests", "workflow_categories"
  add_foreign_key "workflow_stage_templates", "tenants"
  add_foreign_key "workflow_stage_templates", "users", column: "responsible_user_id"
  add_foreign_key "workflow_stage_templates", "workflow_categories"
  add_foreign_key "workflow_stages", "tenants"
  add_foreign_key "workflow_stages", "users", column: "responsible_user_id"
  add_foreign_key "workflow_stages", "workflow_requests"
end
