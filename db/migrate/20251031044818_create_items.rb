class CreateItems < ActiveRecord::Migration[7.2]
  def change
    create_table :items do |t|
      t.string :name, null: false
      t.string :category
      t.integer :position
      t.integer :row_index
      t.boolean :above_basic, default: false, null: false

      t.timestamps
    end
    add_index :items, :name
    add_index :items, [:name, :above_basic], unique: true
  end
end
