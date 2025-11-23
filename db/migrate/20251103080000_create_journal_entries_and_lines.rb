class CreateJournalEntriesAndLines < ActiveRecord::Migration[7.2]
  def change
    drop_table :journals, if_exists: true

    create_table :journal_entries do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :import_batch, null: false, foreign_key: true
      t.date :entry_date, null: false
      t.string :slip_no
      t.string :document_type
      t.string :source_sheet_name
      t.integer :source_start_row
      t.integer :source_end_row
      t.string :summary
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :journal_entries, [:tenant_id, :entry_date]
    add_index :journal_entries, [:tenant_id, :slip_no]

    create_table :journal_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.string :side, null: false # debit or credit
      t.string :account_code
      t.string :account_name, null: false
      t.string :sub_account_name
      t.string :dept_code
      t.string :dept_name
      t.string :vendor_name
      t.bigint :amount, null: false
      t.decimal :tax_amount, precision: 15, scale: 2
      t.string :tax_category
      t.string :tax_calculation
      t.string :memo
      t.integer :source_row_number
      t.jsonb :metadata, null: false, default: {}

      t.timestamps
    end

    add_index :journal_lines, [:journal_entry_id, :side]
    add_index :journal_lines, [:journal_entry_id, :account_name]
  end
end
