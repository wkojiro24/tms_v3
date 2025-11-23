class CreateSnapshots < ActiveRecord::Migration[7.2]
  def change
    create_table :snapshots do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :pl_tree_node, null: false, foreign_key: true
      t.date :period_month, null: false
      t.string :scope_type, null: false
      t.string :scope_key, null: false, default: "company"
      t.bigint :actual_amount, null: false, default: 0
      t.bigint :managed_amount, null: false, default: 0
      t.bigint :fixed_amount, null: false, default: 0
      t.bigint :variable_amount, null: false, default: 0
      t.bigint :unknown_amount, null: false, default: 0
      t.datetime :generated_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :snapshots, [:tenant_id, :period_month, :scope_type, :scope_key, :pl_tree_node_id], unique: true, name: "index_snapshots_on_scope_and_node"
  end
end
