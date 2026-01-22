class CreateWorkflowApprovals < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_approvals do |t|
      t.references :workflow_stage, null: false, foreign_key: true, index: { name: "index_workflow_approvals_on_stage_id" }
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.text :comment
      t.datetime :acted_at, null: false

      t.timestamps
    end
  end
end
