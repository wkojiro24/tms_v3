class CreateWorkflowStages < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_stages do |t|
      t.references :workflow_request, null: false, foreign_key: true, index: { name: "index_workflow_stages_on_request_id" }
      t.integer :position, null: false, default: 1
      t.string :name, null: false
      t.string :status, null: false, default: "pending"
      t.string :responsible_role
      t.references :responsible_user, foreign_key: { to_table: :users }
      t.datetime :activated_at
      t.datetime :completed_at
      t.text :last_comment

      t.timestamps
    end

    add_index :workflow_stages, [:workflow_request_id, :position], name: "index_workflow_stages_on_request_and_position"
    add_index :workflow_stages, :status
  end
end
