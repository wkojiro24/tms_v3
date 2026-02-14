class CreateSalaryDraftDecisions < ActiveRecord::Migration[7.2]
  def change
    create_table :salary_draft_decisions do |t|
      t.references :employee, null: false, foreign_key: true
      t.references :period, null: false, foreign_key: true

      # 選択したパラメータ
      t.integer :selected_grade
      t.string :selected_safety
      t.string :selected_difficulty
      t.integer :position_allowance, default: 0
      t.integer :role_allowance, default: 0

      # 勤怠時間（計算に使用した値）
      t.decimal :overtime_hours, precision: 5, scale: 1, default: 0
      t.decimal :late_night_hours, precision: 5, scale: 1, default: 0
      t.decimal :holiday_hours, precision: 5, scale: 1, default: 0

      # 現行給与（キャッシュ）
      t.integer :current_fixed_total, default: 0
      t.integer :current_gross_total, default: 0
      t.integer :current_net_total, default: 0
      t.integer :current_company_cost, default: 0

      # 新給与（キャッシュ）
      t.integer :proposed_fixed_total, default: 0
      t.integer :proposed_gross_total, default: 0
      t.integer :proposed_net_total, default: 0
      t.integer :proposed_company_cost, default: 0

      # 差額
      t.integer :diff_fixed, default: 0
      t.integer :diff_gross, default: 0
      t.integer :diff_net, default: 0
      t.integer :diff_company_cost, default: 0

      t.string :location
      t.text :notes

      t.timestamps
    end

    add_index :salary_draft_decisions, [:employee_id, :period_id], unique: true
  end
end
