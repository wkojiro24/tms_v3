class AddDepotNameToEmployees < ActiveRecord::Migration[7.2]
  def change
    add_column :employees, :depot_name, :string
    add_index :employees, [:tenant_id, :depot_name]
  end
end
