module Admin
  class VehicleGroupsController < BaseController
    before_action :set_vehicle_group, only: [:edit, :update, :destroy]

    def index
      @vehicle_groups = VehicleGroup.ordered
      @available_codes = available_vehicle_codes
      @ungrouped_codes = ungrouped_vehicle_codes
    end

    def new
      @vehicle_group = VehicleGroup.new(group_type: params[:group_type] || "custom")
      @available_codes = available_vehicle_codes
    end

    def create
      @vehicle_group = VehicleGroup.new(vehicle_group_params)

      if @vehicle_group.save
        redirect_to admin_vehicle_groups_path, notice: "車両グループ「#{@vehicle_group.name}」を作成しました。"
      else
        @available_codes = available_vehicle_codes
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      @available_codes = available_vehicle_codes
    end

    def update
      if @vehicle_group.update(vehicle_group_params)
        redirect_to admin_vehicle_groups_path, notice: "車両グループ「#{@vehicle_group.name}」を更新しました。"
      else
        @available_codes = available_vehicle_codes
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      name = @vehicle_group.name
      @vehicle_group.destroy
      redirect_to admin_vehicle_groups_path, notice: "車両グループ「#{name}」を削除しました。"
    end

    # 営業所別・荷主別グループを自動生成
    def auto_generate
      case params[:type]
      when "shipper"
        VehicleGroup.create_shipper_groups(tenant: ActsAsTenant.current_tenant)
        redirect_to admin_vehicle_groups_path, notice: "荷主別グループを自動生成しました。"
      when "depot"
        VehicleGroup.create_depot_groups(tenant: ActsAsTenant.current_tenant)
        redirect_to admin_vehicle_groups_path, notice: "営業所別グループを自動生成しました。"
      else
        redirect_to admin_vehicle_groups_path, alert: "不明なグループタイプです。"
      end
    end

    # 車両コードを正規化して類似コードをマッピング
    def normalize_codes
      # 類似コードを検出して提案
      @suggestions = detect_similar_codes
    end

    # 疑わしい重複候補を表示
    def suspicious_duplicates
      detector = VehicleSuspiciousDetector.new(ActsAsTenant.current_tenant)
      @candidates = detector.detect_all
    end

    # 疑わしい重複をマージ
    def merge_suspicious
      from_code = params[:from_code]
      to_code = params[:to_code]

      if from_code.blank? || to_code.blank?
        redirect_to suspicious_duplicates_admin_vehicle_groups_path, alert: "コードが指定されていません。"
        return
      end

      detector = VehicleSuspiciousDetector.new(ActsAsTenant.current_tenant)
      result = detector.merge_codes!(from_code: from_code, to_code: to_code, dry_run: false)

      redirect_to suspicious_duplicates_admin_vehicle_groups_path,
        notice: "「#{from_code}」を「#{to_code}」に統合しました（#{result[:records_to_update]}件更新）"
    end

    # 疑わしい重複を無視（今後検出しない）
    def ignore_suspicious
      from_code = params[:from_code]
      to_code = params[:to_code]

      VehicleSuspiciousDetector.add_to_ignore_list(
        tenant: ActsAsTenant.current_tenant,
        code1: from_code,
        code2: to_code
      )

      redirect_to suspicious_duplicates_admin_vehicle_groups_path,
        notice: "「#{from_code}」と「#{to_code}」の組み合わせを無視リストに追加しました。"
    end

    # データ整合性チェック
    def data_audit
      @vehicle_group_id = params[:vehicle_group_id].presence
      @month = params[:month].present? ? Date.strptime(params[:month], "%Y-%m") : nil
      @vehicle_groups = VehicleGroup.ordered
      @available_months = VehicleFinancialMetric.distinct.order(month: :desc).pluck(:month)

      if @vehicle_group_id.present?
        @vehicle_group = VehicleGroup.find(@vehicle_group_id)
        @audit_results = perform_data_audit(@vehicle_group, @month)
      end
    end

    private

    def set_vehicle_group
      @vehicle_group = VehicleGroup.find(params[:id])
    end

    def vehicle_group_params
      params.require(:vehicle_group).permit(:name, :group_type, :position, vehicle_codes: [])
    end

    def available_vehicle_codes
      VehicleFinancialMetric
        .where.not(vehicle_code: [nil, ""])
        .where.not(vehicle_code: excluded_codes)
        .distinct
        .order(:vehicle_code)
        .pluck(:vehicle_code)
    end

    def excluded_codes
      # 77777はメタノール車両グループで使用するため除外しない
      %w[99999 88888 9999 8888 7777 66666 66700 99991 99992]
    end

    def ungrouped_vehicle_codes
      grouped = VehicleGroup.pluck(:vehicle_codes).flatten.compact.uniq
      available_vehicle_codes - grouped
    end

    def detect_similar_codes
      codes = available_vehicle_codes
      suggestions = []

      # 全角・半角ハイフンの違い
      codes.each do |code|
        normalized = code.to_s.unicode_normalize(:nfkc).gsub(/[－ー]/, "-")
        similar = codes.select do |c|
          c != code && c.to_s.unicode_normalize(:nfkc).gsub(/[－ー]/, "-") == normalized
        end
        if similar.present?
          suggestions << { canonical: code, similar: similar, reason: "全角/半角の違い" }
        end
      end

      # 大文字・小文字の違い
      codes.each do |code|
        similar = codes.select do |c|
          c != code && c.to_s.downcase == code.to_s.downcase
        end
        if similar.present? && !suggestions.any? { |s| s[:canonical] == code }
          suggestions << { canonical: code, similar: similar, reason: "大文字/小文字の違い" }
        end
      end

      suggestions.uniq { |s| [s[:canonical], s[:similar].sort].flatten }
    end

    def perform_data_audit(group, month = nil)
      codes = group.vehicle_codes || []
      return { vehicles: [], summary: {} } if codes.empty?

      tenant_id = ActsAsTenant.current_tenant&.id
      scope = VehicleFinancialMetric.where(tenant_id: tenant_id, vehicle_code: codes)
      scope = scope.where(month: month) if month.present?

      vehicles = codes.map do |code|
        vehicle_scope = scope.where(vehicle_code: code)
        months_data = vehicle_scope.distinct.pluck(:month).sort

        # 各指標の値を取得
        revenue = vehicle_scope.where(metric_label: ["輸送収入", "輸送収入計"]).sum(:value_numeric)
        cost_total = vehicle_scope.where(metric_label: "輸送原価計").sum(:value_numeric)
        depreciation = vehicle_scope.where(metric_label: ["減価償却", "減価償却費"]).sum(:value_numeric)
        pnl_recorded = vehicle_scope.where(metric_label: "損益").sum(:value_numeric)
        depot_pnl = vehicle_scope.where(metric_label: "営業所損益").sum(:value_numeric)

        # 検算: 輸送収入 - 輸送原価計 = 営業所損益（に近いはず）
        calc_depot_pnl = revenue.to_f - cost_total.to_f

        # エラーセルがあるか
        error_count = vehicle_scope.where(cell_state: "error").count
        blank_count = vehicle_scope.where(cell_state: "blank").count

        {
          code: code,
          months: months_data,
          month_count: months_data.size,
          revenue: revenue.to_f.round(0),
          cost_total: cost_total.to_f.round(0),
          depreciation: depreciation.to_f.round(0),
          pnl_recorded: pnl_recorded.to_f.round(0),
          depot_pnl: depot_pnl.to_f.round(0),
          calc_depot_pnl: calc_depot_pnl.round(0),
          depot_diff: (depot_pnl.to_f - calc_depot_pnl).round(0),
          error_count: error_count,
          blank_count: blank_count,
          has_data: months_data.present?
        }
      end

      # 合計を計算
      summary = {
        total_revenue: vehicles.sum { |v| v[:revenue] },
        total_cost: vehicles.sum { |v| v[:cost_total] },
        total_depreciation: vehicles.sum { |v| v[:depreciation] },
        total_pnl: vehicles.sum { |v| v[:pnl_recorded] },
        total_depot_pnl: vehicles.sum { |v| v[:depot_pnl] },
        total_calc_depot_pnl: vehicles.sum { |v| v[:calc_depot_pnl] },
        total_depot_diff: vehicles.sum { |v| v[:depot_diff] },
        total_errors: vehicles.sum { |v| v[:error_count] },
        total_blanks: vehicles.sum { |v| v[:blank_count] },
        vehicles_with_data: vehicles.count { |v| v[:has_data] },
        vehicles_without_data: vehicles.count { |v| !v[:has_data] }
      }

      { vehicles: vehicles, summary: summary }
    end
  end
end
