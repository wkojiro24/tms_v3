class AddTenantReferencesToCoreTables < ActiveRecord::Migration[7.2]
  TENANTED_TABLES = %i[
    users
    employees
    employee_assignments
    employee_positions
    employee_statuses
    employee_qualifications
    employee_reviews
    periods
    items
    item_orders
    payroll_column_orders
    payroll_batches
    payroll_cells
    workflow_categories
    workflow_category_notifications
    workflow_stage_templates
    workflow_requests
    workflow_stages
    workflow_approvals
    workflow_notes
  ].freeze

  def up
    TENANTED_TABLES.each do |table|
      add_reference table, :tenant, null: true, foreign_key: true
    end

    adjust_unique_indexes_for_multi_tenancy

    default_tenant_id = create_default_tenant

    TENANTED_TABLES.each do |table|
      execute <<~SQL.squish
        UPDATE #{table}
        SET tenant_id = #{default_tenant_id}
      SQL
    end

    TENANTED_TABLES.each do |table|
      change_column_null table, :tenant_id, false
    end
  end

  def down
    revert_unique_indexes_for_multi_tenancy

    TENANTED_TABLES.reverse_each do |table|
      remove_reference table, :tenant, foreign_key: true
    end
  end

  private

  def adjust_unique_indexes_for_multi_tenancy
    if index_exists?(:users, :email)
      remove_index :users, column: :email
    end
    add_index :users, [:tenant_id, :email], unique: true, name: :index_users_on_tenant_and_email

    if index_exists?(:employees, :employee_code)
      remove_index :employees, column: :employee_code
    end
    add_index :employees, [:tenant_id, :employee_code], unique: true, name: :index_employees_on_tenant_and_employee_code

    if index_exists?(:items, [:name, :above_basic])
      remove_index :items, column: [:name, :above_basic]
    end
    add_index :items, [:tenant_id, :name, :above_basic], unique: true, name: :index_items_on_tenant_name_above_basic

    if index_exists?(:periods, [:year, :month])
      remove_index :periods, column: [:year, :month]
    end
    add_index :periods, [:tenant_id, :year, :month], unique: true, name: :index_periods_on_tenant_year_month

    if index_exists?(:workflow_categories, :code)
      remove_index :workflow_categories, column: :code
    end
    add_index :workflow_categories, [:tenant_id, :code], unique: true, name: :index_workflow_categories_on_tenant_and_code
  end

  def revert_unique_indexes_for_multi_tenancy
    remove_index :users, name: :index_users_on_tenant_and_email
    add_index :users, :email, unique: true

    remove_index :employees, name: :index_employees_on_tenant_and_employee_code
    add_index :employees, :employee_code, unique: true

    remove_index :items, name: :index_items_on_tenant_name_above_basic
    add_index :items, [:name, :above_basic], unique: true

    remove_index :periods, name: :index_periods_on_tenant_year_month
    add_index :periods, [:year, :month], unique: true

    remove_index :workflow_categories, name: :index_workflow_categories_on_tenant_and_code
    add_index :workflow_categories, :code, unique: true
  end

  def create_default_tenant
    tenant_class = Class.new(ActiveRecord::Base) do
      self.table_name = "tenants"
    end

    tenant_class.reset_column_information
    tenant = tenant_class.find_or_create_by!(slug: "default") do |record|
      record.name = "Default Tenant"
      record.time_zone = "Asia/Tokyo"
    end
    tenant.id
  end
end
