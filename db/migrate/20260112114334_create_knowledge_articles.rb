class CreateKnowledgeArticles < ActiveRecord::Migration[7.2]
  def change
    create_table :knowledge_articles do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :author, foreign_key: { to_table: :users }
      t.string :title, null: false
      t.string :slug
      t.text :body
      t.string :category, default: "manual"
      t.string :tags
      t.boolean :published, default: false
      t.datetime :published_at
      t.integer :view_count, default: 0
      t.integer :position, default: 0

      t.timestamps
    end

    add_index :knowledge_articles, [:tenant_id, :slug], unique: true
    add_index :knowledge_articles, [:tenant_id, :category]
    add_index :knowledge_articles, [:tenant_id, :published]
  end
end
