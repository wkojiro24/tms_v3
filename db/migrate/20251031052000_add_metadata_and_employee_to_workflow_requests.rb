class AddMetadataAndEmployeeToWorkflowRequests < ActiveRecord::Migration[7.0]
  def change
    add_column :workflow_requests, :metadata, :jsonb, default: {}, null: false
    add_reference :workflow_requests, :requester_employee, foreign_key: { to_table: :employees }
  end
end
