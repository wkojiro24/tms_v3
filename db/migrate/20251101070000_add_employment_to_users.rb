class AddEmploymentToUsers < ActiveRecord::Migration[7.2]
  def up
    add_reference :users, :employment, null: true, foreign_key: { to_table: :employees }, index: false
    unless index_exists?(:users, :employment_id, unique: true, where: "employment_id IS NOT NULL")
      add_index :users, :employment_id, unique: true, where: "employment_id IS NOT NULL"
    end

    say_with_time "Associating existing users with employments" do
      tenant_class = Class.new(ActiveRecord::Base) do
        self.table_name = "tenants"
      end

      employment_class = Class.new(ActiveRecord::Base) do
        self.table_name = "employees"
      end

      user_class = Class.new(ActiveRecord::Base) do
        self.table_name = "users"
      end

      user_class.reset_column_information
      employment_class.reset_column_information

      user_class.find_each do |user|
        next if user.employment_id.present?

        employment = employment_class.find_by(tenant_id: user.tenant_id, email: user.email)

        unless employment
          tenant = tenant_class.find(user.tenant_id)
          employment = employment_class.create!(
            tenant_id: tenant.id,
            employee_code: generate_employee_code(employment_class, tenant.id, user.email),
            email: user.email,
            full_name: user.email.split("@").first.to_s.titleize,
            current_status: "active",
            hire_date: Date.current
          )
        end

        user.update!(employment_id: employment.id)
      end
    end

    change_column_null :users, :employment_id, false

    execute <<~SQL.squish
      UPDATE workflow_requests wr
      SET requester_employee_id = u.employment_id
      FROM users u
      WHERE wr.requester_id = u.id
        AND wr.requester_employee_id IS NULL
    SQL
  end

  def down
    remove_index :users, :employment_id
    remove_reference :users, :employment, foreign_key: { to_table: :employees }
  end

  private

  def generate_employee_code(employment_class, tenant_id, email)
    base = email.to_s.split("@").first.to_s.gsub(/[^a-zA-Z0-9]/, "").upcase
    base = "USER" if base.blank?

    candidate = base
    suffix = 1

    while employment_class.exists?(tenant_id:, employee_code: candidate)
      candidate = "#{base}-#{format('%02d', suffix)}"
      suffix += 1
    end

    candidate
  end
end
