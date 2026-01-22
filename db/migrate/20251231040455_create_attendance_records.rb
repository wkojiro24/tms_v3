class CreateAttendanceRecords < ActiveRecord::Migration[7.2]
  def change
    # 日次勤怠レコード（King of Time日次データ対応）
    create_table :attendance_records do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: true, foreign_key: true
      t.string :employee_code, null: false
      t.string :employee_name
      t.date :work_date, null: false
      t.string :day_type                    # 平日、法定休日、法定外休日
      t.string :time_zone_category          # 時間帯区分名
      t.string :pattern_name                # パターン名
      t.time :clock_in                      # 出勤時刻
      t.time :clock_out                     # 退勤時刻
      t.string :work_location               # 備考（本社出勤、テレワーク等）
      t.decimal :break_hours, precision: 5, scale: 2  # 休憩時間
      t.timestamps
    end

    add_index :attendance_records, [:tenant_id, :employee_code, :work_date], unique: true, name: 'idx_attendance_tenant_emp_date'
    add_index :attendance_records, [:tenant_id, :work_date]

    # 月次勤怠集計（King of Timeカスタム月次データ対応）
    create_table :attendance_monthlies do |t|
      t.references :tenant, null: false, foreign_key: true
      t.references :employee, null: true, foreign_key: true
      t.string :employee_code, null: false
      t.string :employee_name
      t.string :department_name             # 所属名
      t.integer :year, null: false
      t.integer :month, null: false
      t.decimal :working_days, precision: 5, scale: 2        # 平日出勤日数
      t.decimal :holiday_working_days, precision: 5, scale: 2 # 法定休日出勤日数
      t.decimal :substitute_days, precision: 5, scale: 2     # 代休取得日数
      t.decimal :extra_holiday_days, precision: 5, scale: 2  # 法定外休日出勤日数
      t.decimal :paid_leave_days, precision: 5, scale: 2     # 有休取得日数
      t.decimal :absent_days, precision: 5, scale: 2         # 欠勤取得日数
      t.decimal :total_hours, precision: 6, scale: 2         # 拘束時間
      t.decimal :break_hours, precision: 5, scale: 2         # 休憩時間
      t.decimal :overtime_hours, precision: 5, scale: 2      # 平日残業
      t.decimal :holiday_hours, precision: 5, scale: 2       # 法定休日時間
      t.decimal :extra_holiday_hours, precision: 5, scale: 2 # 法定外休時間
      t.decimal :substitute_holiday_hours, precision: 5, scale: 2 # 法定代休時間
      t.decimal :extra_substitute_hours, precision: 5, scale: 2   # 法定外代時間
      t.decimal :scheduled_overtime, precision: 5, scale: 2  # 所定内残業
      t.decimal :paid_leave_hours, precision: 5, scale: 2    # 有給休暇時間
      t.decimal :late_night_hours, precision: 5, scale: 2    # 深夜残業
      t.timestamps
    end

    add_index :attendance_monthlies, [:tenant_id, :employee_code, :year, :month], unique: true, name: 'idx_attendance_monthly_tenant_emp_ym'
    add_index :attendance_monthlies, [:tenant_id, :year, :month]
  end
end
