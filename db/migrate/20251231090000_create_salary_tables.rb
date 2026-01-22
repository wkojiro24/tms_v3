class CreateSalaryTables < ActiveRecord::Migration[7.2]
  def change
    # 等級別基本給テーブル（評価グレードごとの基本給額）
    create_table :grade_salary_tables do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :grade_level, foreign_key: true
      t.string :grade_code, null: false
      t.string :grade_name
      t.integer :base_salary, null: false, default: 0          # 基本給
      t.integer :city_allowance, default: 0                    # 大都市加算
      t.integer :hourly_rate                                   # 時給（日給制の場合）
      t.decimal :overtime_rate, precision: 4, scale: 2, default: 1.25  # 残業割増率
      t.decimal :late_night_rate, precision: 4, scale: 2, default: 0.25 # 深夜追加割増率
      t.decimal :holiday_rate, precision: 4, scale: 2, default: 1.35   # 休日割増率
      t.date :effective_from
      t.date :effective_until
      t.boolean :active, default: true, null: false
      t.text :notes
      t.timestamps

      t.index [:tenant_id, :grade_code, :effective_from], name: 'idx_grade_salary_tables_unique'
    end

    # 従業員別給与設定（個人の給与条件）
    create_table :salary_settings do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: false, foreign_key: true
      t.string :salary_type, default: 'monthly'               # monthly/daily/hourly
      t.references :grade_salary_table, foreign_key: true     # 適用等級
      t.integer :base_salary_override                          # 基本給上書き（特例）
      t.integer :commuting_allowance, default: 0               # 通勤手当
      t.integer :family_allowance, default: 0                  # 家族手当
      t.integer :housing_allowance, default: 0                 # 住宅手当
      t.integer :position_allowance, default: 0                # 役職手当
      t.integer :qualification_allowance, default: 0           # 資格手当
      t.integer :resident_tax, default: 0                      # 住民税（月額）
      t.integer :dependents_count, default: 0                  # 扶養人数
      t.string :tax_table_type, default: '甲'                  # 税額表（甲/乙）
      t.date :effective_from, null: false
      t.date :effective_until
      t.boolean :active, default: true, null: false
      t.text :notes
      t.timestamps

      t.index [:tenant_id, :employee_id, :effective_from], name: 'idx_salary_settings_unique', unique: true
    end

    # 社会保険料率テーブル
    create_table :insurance_rate_tables do |t|
      t.references :tenant, foreign_key: true
      t.integer :year, null: false
      t.string :prefecture                                     # 都道府県（健康保険料は地域差あり）
      t.decimal :health_insurance_rate, precision: 5, scale: 3 # 健康保険料率（%）
      t.decimal :nursing_insurance_rate, precision: 5, scale: 3 # 介護保険料率（%）
      t.decimal :pension_rate, precision: 5, scale: 3          # 厚生年金料率（%）
      t.decimal :employment_insurance_rate, precision: 5, scale: 3 # 雇用保険料率（%）
      t.boolean :active, default: true, null: false
      t.timestamps

      t.index [:year, :prefecture], name: 'idx_insurance_rate_tables_year_pref'
    end

    # 給与シミュレーション結果
    create_table :salary_simulations do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, foreign_key: true
      t.string :employee_code, null: false
      t.integer :year, null: false
      t.integer :month, null: false
      t.references :attendance_monthly, foreign_key: true
      t.references :salary_setting, foreign_key: true

      # 計算入力値
      t.decimal :working_days, precision: 5, scale: 2
      t.decimal :overtime_hours, precision: 6, scale: 2
      t.decimal :late_night_hours, precision: 6, scale: 2
      t.decimal :holiday_hours, precision: 6, scale: 2
      t.decimal :paid_leave_days, precision: 5, scale: 2

      # 計算結果（支給）
      t.integer :calc_basic_salary, default: 0
      t.integer :calc_overtime_pay, default: 0
      t.integer :calc_late_night_pay, default: 0
      t.integer :calc_holiday_pay, default: 0
      t.integer :calc_paid_leave_pay, default: 0
      t.integer :calc_commuting_allowance, default: 0
      t.integer :calc_other_allowances, default: 0
      t.integer :calc_gross_total, default: 0

      # 計算結果（控除）
      t.integer :calc_health_insurance, default: 0
      t.integer :calc_nursing_insurance, default: 0
      t.integer :calc_pension, default: 0
      t.integer :calc_employment_insurance, default: 0
      t.integer :calc_income_tax, default: 0
      t.integer :calc_resident_tax, default: 0
      t.integer :calc_deduction_total, default: 0

      # 差引
      t.integer :calc_net_total, default: 0

      # 実績との比較
      t.integer :actual_gross_total
      t.integer :actual_net_total
      t.integer :diff_gross
      t.integer :diff_net

      t.string :status, default: 'draft'  # draft/confirmed/error
      t.text :notes
      t.jsonb :calculation_details, default: {}
      t.timestamps

      t.index [:tenant_id, :employee_code, :year, :month], name: 'idx_salary_simulations_unique', unique: true
    end
  end
end
