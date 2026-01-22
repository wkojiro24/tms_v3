class CreateWorkflowCategoryNotifications < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_category_notifications do |t|
      t.references :workflow_category, null: false, foreign_key: true, index: { name: "index_category_notifications_on_category" }
      t.string :role, null: false
      t.string :description

      t.timestamps
    end
  end
end
