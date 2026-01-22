class CreateEmployeeReviews < ActiveRecord::Migration[7.2]
  def change
    create_table :employee_reviews do |t|
      t.references :employee, null: false, foreign_key: true
      t.date :reviewed_on, null: false
      t.string :review_cycle
      t.decimal :score, precision: 5, scale: 2
      t.string :grade
      t.text :summary
      t.text :notes

      t.timestamps
    end
    add_index :employee_reviews, [:employee_id, :reviewed_on], name: "idx_employee_reviews_employee_reviewed_on"
  end
end
