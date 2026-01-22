class AddStandardMonthlyRemunerationToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    # 標準報酬月額（健康保険・厚生年金計算用）
    # 毎年4〜6月の平均報酬から決定（定時決定）
    # または随時改定で変更
    add_column :salary_settings, :standard_monthly_remuneration, :integer

    # 介護保険対象フラグ（40歳以上65歳未満）
    # nilの場合は生年月日から自動判定
    add_column :salary_settings, :nursing_insurance_flag, :boolean
  end
end
