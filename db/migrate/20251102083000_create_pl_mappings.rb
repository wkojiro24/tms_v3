class CreatePlMappings < ActiveRecord::Migration[7.2]
  def change
    create_table :pl_mappings do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :pl_tree_node, null: false, foreign_key: true
      t.integer :priority, null: false, default: 100
      t.string :mapping_scope, null: false, default: "company"
      t.string :account_code
      t.string :account_name
      t.string :vendor_name
      t.string :memo_keyword
      t.string :dept_code
      t.string :vehicle_id
      t.boolean :active, null: false, default: true
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :pl_mappings, [:tenant_id, :priority]
    add_index :pl_mappings, [:tenant_id, :account_code]
    add_index :pl_mappings, [:tenant_id, :vendor_name]
  end
end
