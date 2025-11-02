class CreatePlTreeNodes < ActiveRecord::Migration[7.2]
  def change
    create_table :pl_tree_nodes do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :code, null: false
      t.string :name, null: false
      t.bigint :parent_id
      t.integer :display_order, null: false, default: 0
      t.integer :depth, null: false, default: 0
      t.string :node_type, null: false, default: "normal"
      t.text :expression

      t.timestamps
    end

    add_index :pl_tree_nodes, [:tenant_id, :code], unique: true
    add_index :pl_tree_nodes, [:tenant_id, :parent_id, :display_order], name: "index_pl_tree_nodes_on_tenant_and_parent_and_order"
    add_foreign_key :pl_tree_nodes, :pl_tree_nodes, column: :parent_id
  end
end
