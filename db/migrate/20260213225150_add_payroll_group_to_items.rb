class AddPayrollGroupToItems < ActiveRecord::Migration[7.2]
  def change
    add_column :items, :payroll_group, :string
    add_column :items, :payroll_group_position, :integer
    add_index :items, :payroll_group
  end
end
