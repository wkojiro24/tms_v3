class AddSafetyBonusCumulativeToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    # 無事故継続加算（累計）
    # 賃金規則第16条: 勤続年数に応じて基本給に加算される累計額
    # 最大14,500円（ランク6、勤続10年以上）
    add_column :salary_settings, :safety_bonus_cumulative, :integer, default: 0

    # コメント: この値は時給計算のベースに含まれる
    # 基準内賃金 = 基本給 + 無事故継続加算累計 + 大都市加算 + 職位加算 + 職責加算
  end
end
