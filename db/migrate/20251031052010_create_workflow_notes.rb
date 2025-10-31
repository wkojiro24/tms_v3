class CreateWorkflowNotes < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_notes do |t|
      t.references :workflow_request, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end
  end
end
