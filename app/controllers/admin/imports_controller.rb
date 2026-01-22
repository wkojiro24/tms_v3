module Admin
  class ImportsController < BaseController
    include Admin::ImportsHelper

    before_action :authorize_import

    IMPORT_TYPES = %w[
      journal vehicle_pl account_codes
      payroll attendance employees
      destinations route_distances subcontractors tariffs shippers
      vehicles vehicle_aliases
    ].freeze

    def new
      @periods = Period.ordered.limit(12)
      @recent_imports = current_tenant.import_batches.order(imported_at: :desc).limit(5)
    end

    def create
      import_type = import_params[:import_type]
      files = Array.wrap(import_params[:files]).compact_blank

      unless IMPORT_TYPES.include?(import_type)
        redirect_to new_admin_import_path, alert: "インポート種別を選択してください。" and return
      end

      if files.empty?
        redirect_to new_admin_import_path, alert: "ファイルが選択されていません。" and return
      end

      results = process_import(import_type, files)
      messages = summarize_results(results, import_type)
      has_error = results.any? { |r| r[:status] == :error }

      redirect_to new_admin_import_path, has_error ? { alert: messages } : { notice: messages }
    end

    def template
      type = params[:type]

      unless IMPORT_TYPES.include?(type)
        redirect_to new_admin_import_path, alert: "無効なテンプレート種別です。" and return
      end

      template_data = generate_template(type)
      filename = "#{type}_template.xlsx"

      send_data template_data,
                filename: filename,
                type: "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                disposition: "attachment"
    end

    def histories
      @import_batches = ImportBatch.where(tenant_id: current_tenant.id)
                                   .order(imported_at: :desc)
                                   .limit(50)
    end

    private

    def authorize_import
      authorize! :manage, :admin
    end

    def import_params
      params.require(:import).permit(
        :import_type, :target_month, :location,
        :period_start, :period_end, :replace_period,
        :overwrite, :dry_run,
        files: []
      )
    end

    def process_import(import_type, files)
      case import_type
      when "payroll"
        import_payroll(files)
      when "journal"
        import_journal(files)
      when "vehicle_pl"
        import_vehicle_pl(files)
      when "destinations"
        import_master_data(files, :destinations)
      when "route_distances"
        import_master_data(files, :route_distances)
      when "subcontractors"
        import_master_data(files, :subcontractors)
      when "tariffs"
        import_master_data(files, :tariffs)
      when "shippers"
        import_master_data(files, :shippers)
      when "employees"
        import_master_data(files, :employees)
      when "attendance"
        import_master_data(files, :attendance)
      when "vehicles"
        import_master_data(files, :vehicles)
      when "vehicle_aliases"
        import_master_data(files, :vehicle_aliases)
      when "account_codes"
        import_master_data(files, :account_codes)
      else
        [{ status: :error, message: "未対応のインポート種別です" }]
      end
    end

    def import_payroll(files)
      expected_period = parse_period(import_params[:target_month])

      unless expected_period
        return [{ status: :error, message: "対象月は YYYY-MM 形式で入力してください。" }]
      end

      files.map do |file|
        importer = Imports::PayrollImporter.new(
          file,
          uploaded_by: current_user,
          location: import_params[:location],
          expected_period: expected_period,
          period_mode: :strict
        )
        result = importer.call
        {
          status: result.hard_error? ? :error : :success,
          created: result.created,
          updated: result.updated,
          skipped: result.skipped,
          warnings: result.warnings,
          errors: result.errors
        }
      end
    end

    def import_journal(files)
      files.map do |file|
        # Rooはファイル拡張子で形式を判断するため、正しい拡張子を持つ一時ファイルを作成
        original_ext = File.extname(file.original_filename)
        temp_path = nil

        begin
          temp_file = Tempfile.new(["journal_import", original_ext])
          temp_path = temp_file.path
          temp_file.binmode
          temp_file.write(file.read)
          temp_file.close

          Rails.logger.info "[JournalImport] Processing: #{file.original_filename}, temp_path: #{temp_path}, ext: #{original_ext}"

          importer = Imports::JournalImporter.new(
            tenant: current_tenant,
            file_path: temp_path,
            source_file_name: file.original_filename,
            options: {
              period_start: import_params[:period_start],
              period_end: import_params[:period_end],
              replace_period: import_params[:replace_period] == "1"
            }
          )
          batch = importer.call
          entry_count = batch.journal_entries.count

          Rails.logger.info "[JournalImport] Result: #{entry_count} entries created"

          warnings = []
          if entry_count.zero?
            warnings << "インポートされたデータが0件です。ファイル形式を確認してください。（ヘッダー行が3-4行目にあり、借方/貸方の金額列が含まれている必要があります）"
          end

          {
            status: entry_count.zero? ? :error : :success,
            created: entry_count,
            updated: 0,
            skipped: 0,
            warnings: warnings,
            errors: entry_count.zero? ? ["有効な仕訳データが見つかりませんでした"] : []
          }
        rescue StandardError => e
          Rails.logger.error "[JournalImport] Error: #{e.class} - #{e.message}"
          Rails.logger.error e.backtrace.first(5).join("\n")
          { status: :error, message: e.message }
        ensure
          File.unlink(temp_path) if temp_path && File.exist?(temp_path)
        end
      end
    end

    def import_vehicle_pl(files)
      files.map do |file|
        result = VehicleFinancialImporter.import_from_uploaded_file(file)
        {
          status: result[:errors].present? ? :error : :success,
          created: result[:created] || 0,
          updated: result[:updated] || 0,
          skipped: result[:skipped] || 0,
          warnings: result[:warnings] || [],
          errors: result[:errors] || []
        }
      rescue StandardError => e
        { status: :error, message: e.message }
      end
    end

    def import_master_data(files, type)
      dry_run = import_params[:dry_run] == "1"
      overwrite = import_params[:overwrite] == "1"

      files.map do |file|
        importer = Imports::MasterDataImporter.new(
          tenant: current_tenant,
          file: file,
          data_type: type,
          dry_run: dry_run,
          overwrite: overwrite,
          uploaded_by: current_user
        )
        importer.call
      rescue StandardError => e
        Rails.logger.error("[MasterDataImporter] #{e.class}: #{e.message}")
        { status: :error, message: e.message }
      end
    end

    def parse_period(value)
      return if value.blank?
      return unless value.match?(/\A\d{4}-\d{2}\z/)

      year, month = value.split("-").map(&:to_i)
      Date.new(year, month, 1)
    rescue ArgumentError
      nil
    end

    def summarize_results(results, import_type)
      total_created = results.sum { |r| r[:created] || 0 }
      total_updated = results.sum { |r| r[:updated] || 0 }
      total_skipped = results.sum { |r| r[:skipped] || 0 }

      type_label = import_type_label(import_type)
      messages = ["#{type_label}インポート完了：作成 #{total_created} / 更新 #{total_updated} / スキップ #{total_skipped}"]

      results.each do |result|
        (result[:warnings] || []).each do |warn|
          msg = warn.is_a?(Hash) ? warn[:message] : warn.to_s
          messages << "警告: #{msg}"
        end
        (result[:errors] || []).each do |error|
          msg = error.is_a?(Hash) ? error[:message] : error.to_s
          messages << "エラー: #{msg}"
        end
        messages << "エラー: #{result[:message]}" if result[:message].present?
      end

      messages.join("\n")
    end

    def generate_template(type)
      package = Axlsx::Package.new
      workbook = package.workbook

      case type
      when "destinations"
        workbook.add_worksheet(name: "届け先台帳") do |sheet|
          sheet.add_row %w[届け先コード 届け先名 郵便番号 住所 電話番号 荷主コード 備考]
          sheet.add_row %w[D001 〇〇物流センター 123-4567 東京都○○区○○1-2-3 03-1234-5678 S001 夜間配送可]
        end
      when "route_distances"
        workbook.add_worksheet(name: "拠点間距離") do |sheet|
          sheet.add_row %w[出発地コード 到着地コード 距離(km) 所要時間(分) 備考]
          sheet.add_row ["本社", "D001", 45.5, 60, "一般道経由"]
        end
      when "subcontractors"
        workbook.add_worksheet(name: "傭車先マスタ") do |sheet|
          sheet.add_row %w[傭車先コード 会社名 郵便番号 住所 電話番号 FAX 担当者名 単価区分 備考]
          sheet.add_row %w[C001 〇〇運送株式会社 123-4567 東京都○○区 03-1234-5678 03-1234-5679 田中 A]
        end
      when "tariffs"
        workbook.add_worksheet(name: "タリフ") do |sheet|
          sheet.add_row %w[タリフコード 荷主コード 出発地 到着地 車格 重量区分 単価 有効開始日 有効終了日]
          sheet.add_row ["T001", "S001", "本社", "D001", "4t", "1000kg以下", 15000, "2024-04-01", ""]
        end
      when "shippers"
        workbook.add_worksheet(name: "荷主マスタ") do |sheet|
          sheet.add_row %w[荷主コード 荷主名 郵便番号 住所 電話番号 FAX 担当者名 請求締日 支払サイト 備考]
          sheet.add_row %w[S001 株式会社〇〇 123-4567 東京都○○区 03-1234-5678 03-1234-5679 山田 末締め 翌月末]
        end
      when "employees"
        workbook.add_worksheet(name: "社員マスタ") do |sheet|
          sheet.add_row %w[社員番号 姓 名 姓カナ 名カナ 生年月日 入社日 部門コード 職種コード 役職コード 雇用形態 メール 電話番号]
          sheet.add_row ["E001", "山田", "太郎", "ヤマダ", "タロウ", "1985-04-01", "2020-04-01", "D01", "J01", "P01", "full_time", "yamada@example.com", "090-1234-5678"]
        end
      when "attendance"
        workbook.add_worksheet(name: "勤怠データ") do |sheet|
          sheet.add_row %w[社員番号 日付 出勤時刻 退勤時刻 休憩時間(分) 時間外(分) 深夜(分) 備考]
          sheet.add_row ["E001", "2024-12-01", "08:00", "17:30", 60, 30, 0, ""]
        end
      when "vehicles"
        workbook.add_worksheet(name: "車両マスタ") do |sheet|
          sheet.add_row %w[車両番号 車格 メーカー 車種 年式 初度登録日 車検満了日 ステータス 担当ドライバー 備考]
          sheet.add_row ["品川100あ12-34", "4t", "いすゞ", "エルフ", 2020, "2020-04-01", "2026-04-01", "active", "E001", ""]
        end
      when "vehicle_aliases"
        workbook.add_worksheet(name: "車両エイリアス") do |sheet|
          sheet.add_row %w[車両番号 エイリアス 説明]
          sheet.add_row ["品川100あ12-34", "12-34", "社内略称"]
        end
      when "account_codes"
        workbook.add_worksheet(name: "勘定科目マスタ") do |sheet|
          sheet.add_row %w[科目コード 科目名 科目区分 親科目コード 表示順 備考]
          sheet.add_row ["511", "燃料費", "expense", "", 100, ""]
        end
      end

      package.to_stream.read
    end
  end
end
