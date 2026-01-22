class CreateMaintenanceCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :maintenance_categories do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :color

      t.timestamps
    end

    add_index :maintenance_categories, :key, unique: true
  end
end
