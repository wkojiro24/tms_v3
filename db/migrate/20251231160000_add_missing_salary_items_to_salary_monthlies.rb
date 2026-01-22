class AddMissingSalaryItemsToSalaryMonthlies < ActiveRecord::Migration[7.2]
  def change
    # 勤怠関連（追加）
    add_column :salary_monthlies, :statutory_holiday_days, :decimal, precision: 5, scale: 2
    add_column :salary_monthlies, :non_statutory_holiday_days, :decimal, precision: 5, scale: 2
    add_column :salary_monthlies, :absence_days, :decimal, precision: 5, scale: 2
    add_column :salary_monthlies, :statutory_holiday_hours, :decimal, precision: 6, scale: 2
    add_column :salary_monthlies, :non_statutory_holiday_hours, :decimal, precision: 6, scale: 2

    # 支給項目（基準内賃金）
    add_column :salary_monthlies, :position_allowance, :integer, default: 0  # 職位加算
    add_column :salary_monthlies, :role_allowance, :integer, default: 0      # 職責加算
    add_column :salary_monthlies, :adjustment_salary, :integer, default: 0   # 調整給

    # 支給項目（基準外賃金）
    add_column :salary_monthlies, :adjustment_allowance, :integer, default: 0  # 調整加算
    add_column :salary_monthlies, :absence_deduction, :integer, default: 0     # 欠勤控除
  end
end
