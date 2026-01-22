module Admin
  class AttendancesController < BaseController
    SORT_OPTIONS = {
      'overtime_desc' => { label: '残業時間（多い順）', order: ->(m) { -m.total_overtime } },
      'overtime_asc' => { label: '残業時間（少ない順）', order: ->(m) { m.total_overtime } },
      'working_days_desc' => { label: '出勤日数（多い順）', order: ->(m) { -(m.working_days || 0) } },
      'working_days_asc' => { label: '出勤日数（少ない順）', order: ->(m) { m.working_days || 0 } },
      'total_hours_desc' => { label: '拘束時間（多い順）', order: ->(m) { -(m.total_hours || 0) } },
      'late_night_desc' => { label: '深夜残業（多い順）', order: ->(m) { -(m.late_night_hours || 0) } },
      'paid_leave_desc' => { label: '有休取得（多い順）', order: ->(m) { -(m.paid_leave_days || 0) } },
      'name_asc' => { label: '氏名順', order: ->(m) { m.employee_name || '' } },
      'department' => { label: '所属順', order: ->(m) { [m.department_name || '', m.employee_name || ''] } }
    }.freeze

    def index
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month
      @sort = params[:sort].presence || 'overtime_desc'
      @sort_options = SORT_OPTIONS

      base_monthlies = current_tenant.attendance_monthlies.for_period(@year, @month)

      # ソート適用
      sort_proc = SORT_OPTIONS[@sort]&.fetch(:order) || SORT_OPTIONS['overtime_desc'][:order]
      @monthlies = base_monthlies.to_a.sort_by(&sort_proc)

      @departments = @monthlies.map(&:department_name).uniq.compact.sort

      # 部門別集計
      @department_stats = @monthlies.group_by(&:department_name).transform_values do |records|
        {
          count: records.size,
          total_overtime: records.sum(&:total_overtime),
          avg_overtime: records.sum(&:total_overtime) / records.size.to_f,
          warnings: records.count(&:overtime_warning?),
          criticals: records.count(&:overtime_critical?)
        }
      end

      # 全体サマリー
      @summary = {
        total_employees: @monthlies.size,
        total_overtime: @monthlies.sum(&:total_overtime),
        avg_overtime: @monthlies.any? ? (@monthlies.sum(&:total_overtime) / @monthlies.size.to_f).round(1) : 0,
        warnings: @monthlies.count(&:overtime_warning?),
        criticals: @monthlies.count(&:overtime_critical?)
      }

      # ランキング（Top 10）
      @overtime_ranking = @monthlies.sort_by { |m| -m.total_overtime }.first(10)
      @working_days_ranking = @monthlies.sort_by { |m| -(m.working_days || 0) }.first(10)
      @late_night_ranking = @monthlies.sort_by { |m| -(m.late_night_hours || 0) }.first(10)
      @paid_leave_ranking = @monthlies.sort_by { |m| -(m.paid_leave_days || 0) }.first(10)

      # 部門別ランキング
      @dept_overtime_ranking = @department_stats.sort_by { |_, v| -v[:total_overtime] }
      @dept_avg_overtime_ranking = @department_stats.sort_by { |_, v| -v[:avg_overtime] }
    end

    def show
      @employee_code = params[:id]
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month

      @monthly = current_tenant.attendance_monthlies
        .find_by(employee_code: @employee_code, year: @year, month: @month)

      start_date = Date.new(@year, @month, 1)
      end_date = start_date.end_of_month

      @daily_records = current_tenant.attendance_records
        .for_employee(@employee_code)
        .for_period(start_date, end_date)
        .ordered

      # 全期間の月次データ（推移表示用）
      @all_monthly_data = current_tenant.attendance_monthlies
        .for_employee(@employee_code)
        .order(:year, :month)

      # 年間推移データ（選択年）
      @yearly_data = @all_monthly_data.select { |m| m.year == @year }

      # 年度累計
      @yearly_summary = {
        total_overtime: @yearly_data.sum(&:total_overtime),
        total_paid_leave: @yearly_data.sum { |m| m.paid_leave_days || 0 },
        total_working_days: @yearly_data.sum { |m| m.working_days || 0 },
        total_late_night: @yearly_data.sum { |m| m.late_night_hours || 0 },
        months_count: @yearly_data.size
      }

      # 利用可能な年のリスト
      @available_years = @all_monthly_data.map(&:year).uniq.sort.reverse

      # 給与データ
      @salary_monthly = current_tenant.salary_monthlies
        .find_by(employee_code: @employee_code, year: @year, month: @month, payment_type: 'regular')

      # 年間給与データ（推移表示用）
      @all_salary_data = current_tenant.salary_monthlies
        .for_employee(@employee_code)
        .regular_payments
        .order(:year, :month)

      @yearly_salary_data = @all_salary_data.select { |s| s.year == @year }

      # 年間給与累計
      @yearly_salary_summary = {
        total_gross: @yearly_salary_data.sum { |s| s.gross_total || 0 },
        total_net: @yearly_salary_data.sum { |s| s.net_total || 0 },
        total_deduction: @yearly_salary_data.sum { |s| s.deduction_total || 0 },
        avg_net: @yearly_salary_data.any? ? (@yearly_salary_data.sum { |s| s.net_total || 0 } / @yearly_salary_data.size) : 0,
        months_count: @yearly_salary_data.size
      }

      # 賞与データ
      @bonuses = current_tenant.salary_monthlies
        .for_employee(@employee_code)
        .bonuses
        .where(year: @year)
        .order(:month)
    end

    def import
      @import_type = params[:import_type] || 'monthly'
    end

    def execute_import
      import_type = params[:import_type]
      file = params[:file]

      if file.blank?
        redirect_to import_admin_attendances_path, alert: 'ファイルを選択してください。'
        return
      end

      importer = AttendanceImporter.new(current_tenant)

      begin
        # 一時ファイルに保存
        temp_path = Rails.root.join('tmp', file.original_filename)
        File.open(temp_path, 'wb') { |f| f.write(file.read) }

        results = if import_type == 'daily'
          importer.import_daily(temp_path)
        else
          importer.import_monthly(temp_path)
        end

        File.delete(temp_path) if File.exist?(temp_path)

        if results[:errors].any?
          flash[:warning] = "インポート完了（一部エラーあり）: #{results[:imported]}件追加, #{results[:updated]}件更新, #{results[:skipped]}件スキップ"
        else
          flash[:notice] = "インポート完了: #{results[:imported]}件追加, #{results[:updated]}件更新"
        end
      rescue => e
        flash[:alert] = "インポートエラー: #{e.message}"
      end

      redirect_to admin_attendances_path
    end

    def bulk_import
      folder_path = Rails.root.join('data', 'kingoftime')

      importer = AttendanceImporter.new(current_tenant)

      # 月次データをインポート
      results = importer.import_folder(folder_path, type: :monthly)

      if results[:errors].any? && results[:errors].size > 10
        flash[:warning] = "インポート完了（エラーあり）: #{results[:imported]}件追加, #{results[:updated]}件更新, #{results[:errors].size}件エラー"
      else
        flash[:notice] = "一括インポート完了: #{results[:imported]}件追加, #{results[:updated]}件更新"
      end

      redirect_to admin_attendances_path
    end
  end
end
