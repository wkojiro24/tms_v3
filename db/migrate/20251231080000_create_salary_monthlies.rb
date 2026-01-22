class CreateSalaryMonthlies < ActiveRecord::Migration[7.2]
  def change
    create_table :salary_monthlies do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, foreign_key: true
      t.string :employee_code, null: false
      t.string :employee_name
      t.string :location  # 拠点名（本社、小名浜、仙台、川崎、東京、九州）
      t.integer :year, null: false
      t.integer :month, null: false
      t.string :payment_type, default: 'regular'  # regular, summer_bonus, winter_bonus

      # 勤怠関連
      t.decimal :working_days, precision: 5, scale: 2        # 平日出勤日数
      t.decimal :paid_leave_days, precision: 5, scale: 2     # 有休日数
      t.decimal :working_hours, precision: 8, scale: 2       # 就労時間
      t.decimal :paid_leave_hours, precision: 6, scale: 2    # 有給休暇時間
      t.decimal :paid_leave_remaining, precision: 5, scale: 2 # 有休残日数

      # 支給項目
      t.integer :basic_salary                   # 基本給
      t.integer :city_allowance                 # 大都市加算
      t.integer :basic_salary_2                 # 基本給2
      t.integer :executive_salary               # 役員報酬
      t.integer :paid_leave_pay                 # 有給休暇（支給）
      t.integer :taxable_total                  # 課税支給合計
      t.integer :commuting_allowance            # 非課税通勤費
      t.integer :nontaxable_total               # 非税支給合計
      t.integer :gross_total                    # 支給合計

      # 控除項目
      t.integer :health_insurance               # 健康保険料
      t.integer :nursing_insurance              # 介護保険料
      t.integer :pension_insurance              # 厚生年金保険
      t.integer :employment_insurance           # 雇用保険料
      t.integer :social_insurance_adjustment    # 社保料調整
      t.integer :social_insurance_total         # 社会保険料計
      t.integer :income_tax                     # 所得税
      t.integer :resident_tax                   # 住民税
      t.integer :deduction_total                # 控除合計

      # 計算結果
      t.integer :taxable_income                 # 課税対象額
      t.integer :net_total                      # 差引支給合計
      t.integer :cash_payment                   # 現金支給額
      t.integer :bank_transfer                  # 振込支給額

      # その他
      t.integer :dependents_count               # 扶養人数
      t.string :tax_table                       # 税額表（甲欄/乙欄）

      t.timestamps
    end

    add_index :salary_monthlies, [:tenant_id, :employee_code, :year, :month, :payment_type],
              unique: true, name: 'idx_salary_monthly_tenant_emp_ym_type'
    add_index :salary_monthlies, [:tenant_id, :year, :month]
    add_index :salary_monthlies, [:tenant_id, :location]
  end
end
