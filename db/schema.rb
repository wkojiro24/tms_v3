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

ActiveRecord::Schema[7.2].define(version: 2025_11_01_075000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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
    t.index ["department_id"], name: "index_employees_on_department_id"
    t.index ["grade_level_id"], name: "index_employees_on_grade_level_id"
    t.index ["job_category_id"], name: "index_employees_on_job_category_id"
    t.index ["job_position_id"], name: "index_employees_on_job_position_id"
    t.index ["submit_enabled"], name: "index_employees_on_submit_enabled"
    t.index ["tenant_id", "department_id"], name: "index_employees_on_tenant_id_and_department_id"
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
    t.index ["name"], name: "index_items_on_name"
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

  create_table "tenants", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.string "time_zone"
    t.jsonb "settings", default: {}, null: false
    t.datetime "deleted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_tenants_on_slug", unique: true
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

  add_foreign_key "departments", "tenants"
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
  add_foreign_key "item_orders", "items"
  add_foreign_key "item_orders", "periods"
  add_foreign_key "item_orders", "tenants"
  add_foreign_key "items", "tenants"
  add_foreign_key "job_categories", "tenants"
  add_foreign_key "job_positions", "tenants"
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
  add_foreign_key "users", "employees", column: "employment_id"
  add_foreign_key "users", "tenants"
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
