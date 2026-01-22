class AddAllSalaryItemsToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    # 基準内賃金（時給計算に使用）
    add_column :salary_settings, :basic_salary_2, :integer, default: 0       # 基本給2
    add_column :salary_settings, :executive_salary, :integer, default: 0     # 役員報酬
    add_column :salary_settings, :role_allowance, :integer, default: 0       # 職責加算（職責加算）

    # 基準外賃金
    add_column :salary_settings, :absence_deduction, :integer, default: 0    # 欠勤控除

    # 控除項目
    add_column :salary_settings, :union_fee, :integer, default: 0            # 組合費
  end
end
