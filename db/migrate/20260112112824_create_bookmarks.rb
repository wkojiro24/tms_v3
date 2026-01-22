class CreateBookmarks < ActiveRecord::Migration[7.2]
  def change
    create_table :bookmarks do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :title, null: false
      t.string :url, null: false
      t.text :description
      t.string :category, default: "general"
      t.string :icon
      t.integer :position, default: 0
      t.boolean :shared, default: true
      t.references :creator, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :bookmarks, [:tenant_id, :category]
    add_index :bookmarks, [:tenant_id, :position]
  end
end
