class CreateWorkflowRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :workflow_requests do |t|
      t.references :workflow_category, null: false, foreign_key: true, index: { name: "index_workflow_requests_on_category_id" }
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :status, null: false, default: "draft"
      t.decimal :amount, precision: 15, scale: 2
      t.string :currency, null: false, default: "JPY"
      t.string :vendor_name
      t.string :vehicle_identifier
      t.date :needed_on
      t.text :summary
      t.text :additional_information
      t.datetime :submitted_at
      t.datetime :finalized_at

      t.timestamps
    end

    add_index :workflow_requests, :status
    add_index :workflow_requests, :submitted_at
  end
end
