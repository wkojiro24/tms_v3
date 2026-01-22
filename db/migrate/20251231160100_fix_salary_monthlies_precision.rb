class FixSalaryMonthliesPrecision < ActiveRecord::Migration[7.2]
  def change
    # 時間カラムの精度を拡張（深夜残業時間などの秒単位データに対応）
    change_column :salary_monthlies, :statutory_holiday_hours, :decimal, precision: 10, scale: 2
    change_column :salary_monthlies, :non_statutory_holiday_hours, :decimal, precision: 10, scale: 2
  end
end
