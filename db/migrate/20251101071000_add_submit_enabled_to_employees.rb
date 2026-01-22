class AddSubmitEnabledToEmployees < ActiveRecord::Migration[7.2]
  def change
    add_column :employees, :submit_enabled, :boolean, null: false, default: false
    add_index :employees, :submit_enabled
  end
end
