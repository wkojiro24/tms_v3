class CreateClassificationRules < ActiveRecord::Migration[7.2]
  def change
    create_table :classification_rules do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :priority, null: false, default: 100
      t.string :nature, null: false
      t.decimal :split_ratio, precision: 5, scale: 2
      t.jsonb :conditions, null: false, default: {}
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :classification_rules, [:tenant_id, :priority]
    add_index :classification_rules, [:tenant_id, :nature]
  end
end
