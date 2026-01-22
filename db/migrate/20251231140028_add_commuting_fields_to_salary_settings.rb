class AddCommutingFieldsToSalarySettings < ActiveRecord::Migration[7.2]
  def change
    # 通勤距離（片道、km）
    add_column :salary_settings, :commuting_distance, :decimal, precision: 5, scale: 1
    # 燃費（km/L）- デフォルト13km/L（自動車）
    add_column :salary_settings, :fuel_efficiency, :decimal, precision: 4, scale: 1, default: 13.0
    # 通勤手段（car: 自動車, motorcycle: 原付, bicycle: 自転車, public: 公共交通機関）
    add_column :salary_settings, :commuting_type, :string, default: 'car'
  end
end
