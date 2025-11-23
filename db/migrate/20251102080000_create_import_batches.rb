class CreateImportBatches < ActiveRecord::Migration[7.2]
  def change
    create_table :import_batches do |t|
      t.references :tenant, null: false, foreign_key: true
      t.string :source_file_name, null: false
      t.string :source_digest
      t.datetime :imported_at, null: false
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :import_batches, [:tenant_id, :source_digest], unique: true
  end
end
