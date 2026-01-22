class CreateWorkflowStageTemplates < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_stage_templates do |t|
      t.references :workflow_category, null: false, foreign_key: true, index: { name: "index_stage_templates_on_category_id" }
      t.integer :position, null: false, default: 1
      t.string :name, null: false
      t.string :responsible_role
      t.references :responsible_user, foreign_key: { to_table: :users }
      t.string :instructions

      t.timestamps
    end

    add_index :workflow_stage_templates, [:workflow_category_id, :position], name: "index_stage_templates_on_category_and_position"
  end
end
