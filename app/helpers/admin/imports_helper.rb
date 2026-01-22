module Admin
  module ImportsHelper
    def import_type_options
      [
        ["── 経営データ ──", nil, { disabled: true }],
        ["仕訳明細", "journal"],
        ["車両原価計算（P/L）", "vehicle_pl"],
        ["勘定科目マスタ", "account_codes"],
        ["── 人事データ ──", nil, { disabled: true }],
        ["給与データ", "payroll"],
        ["勤怠データ", "attendance"],
        ["社員マスタ", "employees"],
        ["── 配車マスタ ──", nil, { disabled: true }],
        ["届け先台帳", "destinations"],
        ["拠点間距離・時間", "route_distances"],
        ["傭車先マスタ", "subcontractors"],
        ["タリフ（運賃表）", "tariffs"],
        ["荷主マスタ", "shippers"],
        ["── 車両データ ──", nil, { disabled: true }],
        ["車両マスタ", "vehicles"],
        ["車両エイリアス", "vehicle_aliases"]
      ]
    end

    def import_type_label(type)
      {
        "journal" => "仕訳明細",
        "vehicle_pl" => "車両原価計算",
        "account_codes" => "勘定科目マスタ",
        "payroll" => "給与データ",
        "attendance" => "勤怠データ",
        "employees" => "社員マスタ",
        "destinations" => "届け先台帳",
        "route_distances" => "拠点間距離",
        "subcontractors" => "傭車先マスタ",
        "tariffs" => "タリフ",
        "shippers" => "荷主マスタ",
        "vehicles" => "車両マスタ",
        "vehicle_aliases" => "車両エイリアス"
      }[type] || type
    end

    def import_status_badge(status)
      case status
      when "completed", "success"
        content_tag(:span, "完了", class: "badge rounded-pill text-bg-success")
      when "partial"
        content_tag(:span, "一部成功", class: "badge rounded-pill text-bg-warning")
      when "error", "failed"
        content_tag(:span, "エラー", class: "badge rounded-pill text-bg-danger")
      when "processing"
        content_tag(:span, "処理中", class: "badge rounded-pill text-bg-info")
      else
        content_tag(:span, "不明", class: "badge rounded-pill text-bg-secondary")
      end
    end
  end
end
