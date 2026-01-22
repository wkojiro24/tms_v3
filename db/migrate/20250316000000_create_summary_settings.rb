class CreateSummarySettings < ActiveRecord::Migration[7.0]
  def change
    create_table :summary_settings do |t|
      t.integer :term_start_month, null: false, default: 9
      t.jsonb :label_mappings, null: false, default: {}
      t.references :tenant, foreign_key: true
      t.timestamps
    end
  end
end
