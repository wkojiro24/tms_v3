class AddAdjustmentFieldsToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    # 月次調整項目（毎月変動する可能性がある項目）
    add_column :salary_settings, :adjustment_salary, :integer, default: 0    # 調整給
    add_column :salary_settings, :adjustment_allowance, :integer, default: 0 # 調整加算
  end
end
