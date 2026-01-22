class CreateAnnouncements < ActiveRecord::Migration[7.2]
  def change
    create_table :announcements do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :title, null: false
      t.text :body
      t.string :category, default: "general"
      t.datetime :published_at
      t.datetime :expires_at
      t.boolean :pinned, default: false
      t.references :author, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :announcements, [:tenant_id, :published_at]
    add_index :announcements, [:tenant_id, :category]
  end
end
