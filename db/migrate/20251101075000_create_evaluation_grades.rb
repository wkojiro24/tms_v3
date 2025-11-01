class CreateEvaluationGrades < ActiveRecord::Migration[7.2]
  def change
    create_table :evaluation_grades do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.string :band
      t.boolean :active, null: false, default: true
      t.integer :score

      t.timestamps
    end
    add_index :evaluation_grades, [:tenant_id, :code], unique: true

    add_reference :employee_reviews, :grade_level, foreign_key: true
    add_reference :employee_reviews, :evaluation_grade, foreign_key: true
  end
end
