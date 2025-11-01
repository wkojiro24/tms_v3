class CreateEvaluationCycles < ActiveRecord::Migration[7.2]
  def change
    create_table :evaluation_cycles do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.text :description
      t.date :start_on
      t.date :end_on
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :evaluation_cycles, [:tenant_id, :code], unique: true

    add_reference :employee_reviews, :evaluation_cycle, foreign_key: true
  end
end
