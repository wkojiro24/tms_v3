class CreateWorkflowCategories < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_categories do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.text :description
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :workflow_categories, :code, unique: true
  end
end
