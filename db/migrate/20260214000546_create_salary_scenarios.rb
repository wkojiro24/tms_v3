class CreateSalaryScenarios < ActiveRecord::Migration[7.2]
  def change
    # シミュレーションシナリオ
    create_table :salary_scenarios do |t|
      t.references :tenant, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.jsonb :parameters, default: {}
      t.boolean :is_baseline, default: false
      t.timestamps
    end

    # 手当項目定義
    create_table :salary_scenario_items do |t|
      t.references :salary_scenario, null: false, foreign_key: true
      t.string :name, null: false
      t.string :category  # base, allowance, variable
      t.string :calculation_type, default: "fixed"  # fixed, hourly, formula
      t.integer :default_amount, default: 0
      t.string :formula
      t.integer :position, default: 0
      t.timestamps
    end

    # 試算結果
    create_table :salary_scenario_results do |t|
      t.references :salary_scenario, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.references :period, foreign_key: true
      t.integer :base_salary, default: 0
      t.integer :total_allowances, default: 0
      t.integer :overtime_pay, default: 0
      t.integer :late_night_pay, default: 0
      t.integer :holiday_pay, default: 0
      t.integer :gross_pay, default: 0
      t.integer :deductions, default: 0
      t.integer :net_pay, default: 0
      t.jsonb :calculation_details, default: {}
      t.timestamps

      t.index [:salary_scenario_id, :employee_id], unique: true, name: "idx_scenario_employee"
    end
  end
end
