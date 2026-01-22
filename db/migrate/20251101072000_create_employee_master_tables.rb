class CreateEmployeeMasterTables < ActiveRecord::Migration[7.2]
  def change
    create_table :departments do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :departments, [:tenant_id, :code], unique: true

    create_table :job_categories do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :job_categories, [:tenant_id, :code], unique: true

    create_table :job_positions do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true
      t.integer :grade

      t.timestamps
    end
    add_index :job_positions, [:tenant_id, :code], unique: true

    create_table :grade_levels do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :grade_levels, [:tenant_id, :code], unique: true
  end
end
