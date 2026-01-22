# frozen_string_literal: true

namespace :simulation do
  desc "メタノール車両 減車シミュレーション Excel出力"
  task vehicle_reduction: :environment do
    require "caxlsx"

    ActsAsTenant.current_tenant = Tenant.first

    # === 設定 ===
    # メタノール車両（DBに存在するコード形式）
    # 注: 管理部門シートと一致するコード（5486は含まない）
    # 77777 は管理部門シートに含まれる特殊コード

    # 2024年用の車両コード（9台）
    vehicle_codes_2024 = %w[
      1862-5846 1825-6070
      2363 2919 3148 3219 3247 3320 3677
      77777
    ]

    # 2025年用の車両コード（車両入れ替えあり）
    # - 2919は2025/05以降故障で稼働停止 → 4097が後継（2025/05から）
    # - 3882は新規投入予定だが、今回のシミュレーションには含まない
    # ※ 月別に使用する車両を切り替える
    vehicle_codes_2025_base = %w[
      1862-5846 1825-6070
      2363 3148 3219 3247 3320 3677
      77777
    ]
    # 2025/01-04: 2919を含む（4097はまだない）
    vehicle_codes_2025_jan_apr = vehicle_codes_2025_base + %w[2919]
    # 2025/05以降: 2919の代わりに4097（後継）
    vehicle_codes_2025_may_onward = vehicle_codes_2025_base + %w[4097]

    # 除外する車両（2363と3677）
    excluded_codes = %w[2363 3677]

    # シミュレーション対象車両（2024年用）
    simulation_codes_2024 = vehicle_codes_2024 - excluded_codes
    # シミュレーション対象車両（2025/01-04用）
    simulation_codes_2025_jan_apr = vehicle_codes_2025_jan_apr - excluded_codes
    # シミュレーション対象車両（2025/05以降用）
    simulation_codes_2025_may_onward = vehicle_codes_2025_may_onward - excluded_codes

    # カテゴリ別処理ルール
    # :full_9 = 9台分そのまま
    # :only_7 = 7台分のみ（除外車両を除く）
    category_rules = {
      "revenue" => :full_9,           # 売上: 9台分維持
      "fixed_cost" => :only_7,        # 固定費: 7台分のみ
      "variable_cost" => :full_9,     # 変動費: 9台分維持
      "driver_cost" => :full_9,       # ドライバー人件費: 9台分維持
      "depot_admin" => :full_9,       # 営業所管理費: 9台分維持
      "depot_personnel" => :full_9,   # 営業所人件費: 9台分維持
      "hq_personnel" => :full_9,      # 本社人件費: 9台分維持
      "hq_admin" => :full_9,          # 本社管理費: 9台分維持
      "profit" => :calculate          # 損益: 自動計算
    }

    # === 期間設定 ===
    period_2024 = {
      start_month: Date.new(2024, 1, 1),
      end_month: Date.new(2024, 12, 1),
      label: "2024年1-12月",
      months: (1..12).map { |m| Date.new(2024, m, 1) }
    }
    period_2025 = {
      start_month: Date.new(2025, 1, 1),
      end_month: Date.new(2025, 9, 1),
      label: "2025年1-9月",
      months: (1..9).map { |m| Date.new(2025, m, 1) }
    }

    # === カテゴリとラベルのマッピングを取得 ===
    categories = MetricCategory.order(:position).includes(:items).index_by(&:name)

    # カテゴリ名 => [ラベルの配列] のマッピングを作成
    category_labels = {}
    categories.each do |name, cat|
      labels = cat.items.flat_map { |item| item.source_labels || [] }
      category_labels[name] = labels
    end

    # === 月別データ取得関数 ===
    def fetch_monthly_data_by_month(vehicle_codes, start_month, end_month)
      # { [label, month] => value } の形式で返す
      VehicleFinancialMetric
        .where(vehicle_code: vehicle_codes)
        .where(month: start_month..end_month)
        .group(:metric_label, :month)
        .sum(:value_numeric)
    end

    # 2025年用: 月別に異なる車両コードでデータ取得
    def fetch_monthly_data_2025_mixed(codes_jan_apr, codes_may_onward, months)
      result = {}
      months.each do |month|
        codes = month.month <= 4 ? codes_jan_apr : codes_may_onward
        month_data = VehicleFinancialMetric
          .where(vehicle_code: codes)
          .where(month: month)
          .group(:metric_label)
          .sum(:value_numeric)
        month_data.each do |label, value|
          result[[label, month]] = value
        end
      end
      result
    end

    # === 2024年データ取得 ===
    puts "2024年データ取得中..."
    data_2024_all = fetch_monthly_data_by_month(vehicle_codes_2024, period_2024[:start_month], period_2024[:end_month])
    data_2024_sim = fetch_monthly_data_by_month(simulation_codes_2024, period_2024[:start_month], period_2024[:end_month])

    # === 2025年データ取得 ===
    # 月別に車両コードを切り替え（1-4月: 2919含む、5月以降: 4097+3882）
    puts "2025年データ取得中..."
    data_2025_all = fetch_monthly_data_2025_mixed(
      vehicle_codes_2025_jan_apr,
      vehicle_codes_2025_may_onward,
      period_2025[:months]
    )
    data_2025_sim = fetch_monthly_data_2025_mixed(
      simulation_codes_2025_jan_apr,
      simulation_codes_2025_may_onward,
      period_2025[:months]
    )

    # === シミュレーション値計算（月別） ===
    def calculate_simulation_value_monthly(label, month, category_name, category_rules, data_all, data_sim)
      rule = category_rules[category_name] || :full_9

      case rule
      when :full_9
        data_all[[label, month]] || 0.0
      when :only_7
        data_sim[[label, month]] || 0.0
      else
        data_all[[label, month]] || 0.0
      end
    end

    # === Excel出力 ===
    puts "Excel出力中..."

    package = Axlsx::Package.new
    wb = package.workbook

    # スタイル定義
    styles = wb.styles
    header_style = styles.add_style(
      bg_color: "4472C4",
      fg_color: "FFFFFF",
      b: true,
      sz: 10,
      border: { style: :thin, color: "000000" },
      alignment: { horizontal: :center, vertical: :center }
    )
    category_style = styles.add_style(
      bg_color: "D9E2F3",
      b: true,
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :left }
    )
    label_style = styles.add_style(
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :left }
    )
    number_style = styles.add_style(
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :right },
      format_code: "#,##0"
    )
    negative_style = styles.add_style(
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :right },
      format_code: "#,##0",
      fg_color: "FF0000"
    )
    diff_positive_style = styles.add_style(
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :right },
      format_code: "#,##0",
      fg_color: "008000"
    )
    diff_negative_style = styles.add_style(
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :right },
      format_code: "#,##0",
      fg_color: "FF0000"
    )
    subtotal_style = styles.add_style(
      bg_color: "FFF2CC",
      b: true,
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :right },
      format_code: "#,##0"
    )
    avg_style = styles.add_style(
      bg_color: "E2EFDA",
      b: true,
      sz: 9,
      border: { style: :thin, color: "AAAAAA" },
      alignment: { horizontal: :right },
      format_code: "#,##0"
    )

    # カテゴリ定義（共通）- 詳細項目を順番通りに表示
    # 項目名のマッピング（DBのラベル → 表示名）
    label_display_names = {
      "輸送収入" => "輸送収入",
      "保障額" => "保障額",
      "減価償却費" => "減価償却",
      "自動車税" => "自動車税",
      "自動車重量税" => "自動車重量税・取得税",
      "自動車取得税" => nil,  # 重量税と合算
      "自賠責保険" => "自賠責保険",
      "任意保険合計" => "任意保険",
      "車検" => "車検費用",
      "地代・家賃" => "駐車場・地代",
      "高速代計" => "高速代",
      "軽油費" => "軽油費",
      "その他燃料費" => "その他燃料費",
      "油脂費" => nil,  # その他燃料費と合算
      "タイヤ・チューブ費" => "タイヤ・チューブ",
      "一般修理費" => "その他修繕費",
      "部品費" => nil,  # 修繕費と合算
      "事故費" => nil,  # 修繕費と合算
      "人件費計" => "ドライバー人件費",
      "営業所管理費" => "営業所管理費",
      "営業所人件費" => "営業所人件費",
      "本社人件費" => "本社人件費",
      "本社管理費" => "本社管理費",
      "外注費" => nil  # 本社管理費と合算
    }

    # 表示する項目の順序（カテゴリごと）
    display_categories = [
      {
        display_name: "売上",
        cats: ["revenue"],
        note: "9台分維持",
        items: [
          { labels: ["輸送収入"], display: "輸送収入" }
        ]
      },
      {
        display_name: "固定費",
        cats: ["fixed_cost"],
        note: "7台分のみ",
        items: [
          { labels: ["減価償却費"], display: "減価償却" },
          { labels: ["自動車税"], display: "自動車税" },
          { labels: ["自動車重量税", "自動車取得税"], display: "自動車重量税・取得税" },
          { labels: ["自賠責保険"], display: "自賠責保険" },
          { labels: ["任意保険合計"], display: "任意保険" },
          { labels: ["車検"], display: "車検費用" },
          { labels: ["地代・家賃"], display: "駐車場・地代" }
        ]
      },
      {
        display_name: "変動費",
        cats: ["variable_cost"],
        note: "9台分維持",
        items: [
          { labels: ["高速代計"], display: "高速代" },
          { labels: ["軽油費"], display: "軽油費" },
          { labels: ["その他燃料費", "油脂費"], display: "その他燃料費" },
          { labels: ["タイヤ・チューブ費"], display: "タイヤ・チューブ" },
          { labels: ["一般修理費", "部品費", "事故費"], display: "その他修繕費" }
        ]
      },
      {
        display_name: "ドライバー人件費",
        cats: ["driver_cost"],
        note: "9台分維持",
        items: [
          { labels: ["人件費計"], display: "ドライバー人件費" }
        ]
      },
      {
        display_name: "営業所経費",
        cats: ["depot_admin", "depot_personnel"],
        note: "9台分維持",
        items: [
          { labels: ["営業所管理費", "営業所人件費"], display: "営業所経費" }
        ]
      },
      {
        display_name: "本社経費",
        cats: ["hq_personnel", "hq_admin"],
        note: "9台分維持",
        items: [
          { labels: ["本社人件費", "本社管理費", "外注費"], display: "本社経費" }
        ]
      }
    ]

    # === シート作成用の共通処理 ===
    def create_monthly_sheet(wb, sheet_name, period, data_all, data_sim, category_rules, category_labels, display_categories, styles_hash)
      header_style = styles_hash[:header]
      category_style = styles_hash[:category]
      label_style = styles_hash[:label]
      number_style = styles_hash[:number]
      negative_style = styles_hash[:negative]
      diff_positive_style = styles_hash[:diff_positive]
      diff_negative_style = styles_hash[:diff_negative]
      subtotal_style = styles_hash[:subtotal]
      avg_style = styles_hash[:avg]
      styles = styles_hash[:styles]

      months = period[:months]
      month_count = months.length

      wb.add_worksheet(name: sheet_name) do |sheet|
        sheet.add_row ["メタノール車両 減車シミュレーション（月別）"], style: styles.add_style(b: true, sz: 14)
        sheet.add_row ["期間: #{period[:label]}"]
        sheet.add_row ["現状: 9台 → シミュレーション: 7台（2363, 3677除外）"]
        if sheet_name.include?("2025")
          sheet.add_row ["※ 2025/01-04: 2919稼働、2025/05以降: 4097（後継）に入替"]
        end
        sheet.add_row []

        # ヘッダー行
        header_row = ["カテゴリ", "項目名"]
        months.each { |m| header_row << m.strftime("%Y/%m") }
        header_row += ["平均", "備考"]
        sheet.add_row header_row, style: header_style

        # 現状データ
        sheet.add_row ["【現状（9台）】"], style: styles.add_style(b: true, sz: 11, bg_color: "DCE6F1")

        category_totals_current = {}
        display_categories.each do |display_cat|
          category_totals_current[display_cat[:display_name]] = Array.new(month_count, 0.0)
        end

        display_categories.each do |display_cat|
          first_item = true

          display_cat[:items].each do |item|
            row_data = [first_item ? display_cat[:display_name] : "", item[:display]]
            first_item = false
            month_values = []

            months.each_with_index do |month, idx|
              # 複数ラベルの合計
              val = item[:labels].sum { |lbl| data_all[[lbl, month]] || 0.0 }
              month_values << val
              category_totals_current[display_cat[:display_name]][idx] += val
              row_data << val.round(0)
            end

            avg_val = month_values.sum / month_count
            row_data << avg_val.round(0)
            row_data << ""  # 現状データには備考不要

            row_styles = [category_style, label_style] + Array.new(month_count + 1, number_style) + [label_style]
            sheet.add_row row_data, style: row_styles
          end
        end

        # 現状の損益行
        revenue_current = category_totals_current["売上"]
        cost_current_monthly = months.each_with_index.map do |_, idx|
          category_totals_current.except("売上").values.sum { |arr| arr[idx] }
        end
        profit_current = revenue_current.zip(cost_current_monthly).map { |r, c| r - c }

        row_data = ["損益", ""]
        profit_current.each { |v| row_data << v.round(0) }
        row_data << (profit_current.sum / month_count).round(0)
        row_data << ""
        row_styles = [category_style, label_style] + profit_current.map { |v| v < 0 ? negative_style : subtotal_style } + [subtotal_style, label_style]
        sheet.add_row row_data, style: row_styles

        sheet.add_row []

        # シミュレーションデータ
        sheet.add_row ["【シミュレーション（7台）】"], style: styles.add_style(b: true, sz: 11, bg_color: "FCE4D6")

        category_totals_sim = {}
        display_categories.each do |display_cat|
          category_totals_sim[display_cat[:display_name]] = Array.new(month_count, 0.0)
        end

        display_categories.each do |display_cat|
          first_item = true
          # カテゴリのルール（最初のcatを使用）
          cat_rule_name = display_cat[:cats].first

          display_cat[:items].each do |item|
            row_data = [first_item ? display_cat[:display_name] : "", item[:display]]
            first_item = false
            month_values = []

            months.each_with_index do |month, idx|
              # 複数ラベルの合計（シミュレーションルール適用）
              val = item[:labels].sum do |lbl|
                calculate_simulation_value_monthly(lbl, month, cat_rule_name, category_rules, data_all, data_sim)
              end
              month_values << val
              category_totals_sim[display_cat[:display_name]][idx] += val
              row_data << val.round(0)
            end

            avg_val = month_values.sum / month_count
            row_data << avg_val.round(0)
            row_data << display_cat[:note]

            row_styles = [category_style, label_style] + Array.new(month_count + 1, number_style) + [label_style]
            sheet.add_row row_data, style: row_styles
          end
        end

        # シミュレーションの損益行
        revenue_sim = category_totals_sim["売上"]
        cost_sim_monthly = months.each_with_index.map do |_, idx|
          category_totals_sim.except("売上").values.sum { |arr| arr[idx] }
        end
        profit_sim = revenue_sim.zip(cost_sim_monthly).map { |r, c| r - c }

        row_data = ["損益", ""]
        profit_sim.each { |v| row_data << v.round(0) }
        row_data << (profit_sim.sum / month_count).round(0)
        row_data << ""
        row_styles = [category_style, label_style] + profit_sim.map { |v| v < 0 ? negative_style : subtotal_style } + [subtotal_style, label_style]
        sheet.add_row row_data, style: row_styles

        sheet.add_row []

        # 差額
        sheet.add_row ["【差額（シミュレ - 現状）】"], style: styles.add_style(b: true, sz: 11, bg_color: "E2EFDA")

        display_categories.each do |display_cat|
          row_data = [display_cat[:display_name], ""]
          diff_values = []

          months.each_with_index do |_, idx|
            diff = category_totals_sim[display_cat[:display_name]][idx] - category_totals_current[display_cat[:display_name]][idx]
            diff_values << diff
            row_data << diff.round(0)
          end

          avg_diff = diff_values.sum / month_count
          row_data << avg_diff.round(0)
          row_data << ""

          row_styles = [category_style, label_style] + diff_values.map { |v| v >= 0 ? diff_positive_style : diff_negative_style } + [avg_style, label_style]
          sheet.add_row row_data, style: row_styles
        end

        # 損益差額
        profit_diff = profit_sim.zip(profit_current).map { |s, c| s - c }
        row_data = ["【損益差額】", ""]
        profit_diff.each { |v| row_data << v.round(0) }
        row_data << (profit_diff.sum / month_count).round(0)
        row_data << (profit_diff.sum > 0 ? "改善" : "悪化")
        row_styles = [category_style, label_style] + profit_diff.map { |v| v >= 0 ? diff_positive_style : diff_negative_style } + [avg_style, label_style]
        sheet.add_row row_data, style: row_styles

        # 列幅調整
        sheet.column_widths 14, 20, *Array.new(month_count, 10), 10, 12
      end
    end

    styles_hash = {
      styles: styles,
      header: header_style,
      category: category_style,
      label: label_style,
      number: number_style,
      negative: negative_style,
      diff_positive: diff_positive_style,
      diff_negative: diff_negative_style,
      subtotal: subtotal_style,
      avg: avg_style
    }

    # === シート1: 2024年月別 ===
    create_monthly_sheet(wb, "2024年 月別", period_2024, data_2024_all, data_2024_sim, category_rules, category_labels, display_categories, styles_hash)

    # === シート2: 2025年月別 ===
    create_monthly_sheet(wb, "2025年 月別", period_2025, data_2025_all, data_2025_sim, category_rules, category_labels, display_categories, styles_hash)

    # === シート3: サマリー比較 ===
    wb.add_worksheet(name: "サマリー比較") do |sheet|
      sheet.add_row ["メタノール車両 減車シミュレーション サマリー"], style: styles.add_style(b: true, sz: 14)
      sheet.add_row ["※月次平均で比較"]
      sheet.add_row []

      sheet.add_row ["", "2024年月次平均", "", "", "2025年月次平均", "", ""], style: header_style
      sheet.add_row ["カテゴリ", "現状", "シミュレ", "差額", "現状", "シミュレ", "差額"], style: header_style

      # 2024年データ集計
      cat_2024_current = Hash.new { |h, k| h[k] = 0.0 }
      cat_2024_sim = Hash.new { |h, k| h[k] = 0.0 }
      category_order = %w[revenue fixed_cost variable_cost driver_cost depot_admin depot_personnel hq_personnel hq_admin]

      category_order.each do |cat_name|
        cat = categories[cat_name]
        next unless cat
        cat_labels = category_labels[cat_name] || []
        cat_labels.each do |label|
          period_2024[:months].each do |month|
            cat_2024_current[cat_name] += (data_2024_all[[label, month]] || 0.0)
            cat_2024_sim[cat_name] += calculate_simulation_value_monthly(label, month, cat_name, category_rules, data_2024_all, data_2024_sim)
          end
        end
      end
      # 月次平均に変換
      cat_2024_current.transform_values! { |v| v / 12.0 }
      cat_2024_sim.transform_values! { |v| v / 12.0 }

      # 2025年データ集計
      cat_2025_current = Hash.new { |h, k| h[k] = 0.0 }
      cat_2025_sim = Hash.new { |h, k| h[k] = 0.0 }

      category_order.each do |cat_name|
        cat = categories[cat_name]
        next unless cat
        cat_labels = category_labels[cat_name] || []
        cat_labels.each do |label|
          period_2025[:months].each do |month|
            cat_2025_current[cat_name] += (data_2025_all[[label, month]] || 0.0)
            cat_2025_sim[cat_name] += calculate_simulation_value_monthly(label, month, cat_name, category_rules, data_2025_all, data_2025_sim)
          end
        end
      end
      # 月次平均に変換
      cat_2025_current.transform_values! { |v| v / 9.0 }
      cat_2025_sim.transform_values! { |v| v / 9.0 }

      # まとめて表示するカテゴリ定義
      summary_categories = [
        { name: "売上", cats: ["revenue"] },
        { name: "固定費", cats: ["fixed_cost"] },
        { name: "変動費", cats: ["variable_cost"] },
        { name: "ドライバー人件費", cats: ["driver_cost"] },
        { name: "営業所経費", cats: ["depot_admin", "depot_personnel"] },
        { name: "本社経費", cats: ["hq_personnel", "hq_admin"] }
      ]

      summary_categories.each do |summary_cat|
        c_2024 = summary_cat[:cats].sum { |c| cat_2024_current[c] }
        s_2024 = summary_cat[:cats].sum { |c| cat_2024_sim[c] }
        d_2024 = s_2024 - c_2024

        c_2025 = summary_cat[:cats].sum { |c| cat_2025_current[c] }
        s_2025 = summary_cat[:cats].sum { |c| cat_2025_sim[c] }
        d_2025 = s_2025 - c_2025

        sheet.add_row [
          summary_cat[:name],
          c_2024.round(0), s_2024.round(0), d_2024.round(0),
          c_2025.round(0), s_2025.round(0), d_2025.round(0)
        ], style: [category_style, number_style, number_style, d_2024 >= 0 ? diff_positive_style : diff_negative_style, number_style, number_style, d_2025 >= 0 ? diff_positive_style : diff_negative_style]
      end

      # 損益行
      sheet.add_row []
      rev_2024_c = cat_2024_current["revenue"]
      rev_2024_s = cat_2024_sim["revenue"]
      cost_2024_c = cat_2024_current.except("revenue").values.sum
      cost_2024_s = cat_2024_sim.except("revenue").values.sum
      profit_2024_c = rev_2024_c - cost_2024_c
      profit_2024_s = rev_2024_s - cost_2024_s
      profit_2024_d = profit_2024_s - profit_2024_c

      rev_2025_c = cat_2025_current["revenue"]
      rev_2025_s = cat_2025_sim["revenue"]
      cost_2025_c = cat_2025_current.except("revenue").values.sum
      cost_2025_s = cat_2025_sim.except("revenue").values.sum
      profit_2025_c = rev_2025_c - cost_2025_c
      profit_2025_s = rev_2025_s - cost_2025_s
      profit_2025_d = profit_2025_s - profit_2025_c

      sheet.add_row [
        "【損益】",
        profit_2024_c.round(0), profit_2024_s.round(0), profit_2024_d.round(0),
        profit_2025_c.round(0), profit_2025_s.round(0), profit_2025_d.round(0)
      ], style: [category_style, subtotal_style, subtotal_style, profit_2024_d >= 0 ? diff_positive_style : diff_negative_style, subtotal_style, subtotal_style, profit_2025_d >= 0 ? diff_positive_style : diff_negative_style]

      sheet.column_widths 18, 12, 12, 12, 12, 12, 12
    end

    # ファイル出力
    output_path = Rails.root.join("tmp", "methanol_simulation_#{Time.current.strftime('%Y%m%d_%H%M%S')}.xlsx")
    package.serialize(output_path)

    puts "=" * 60
    puts "シミュレーションExcel出力完了!"
    puts "ファイル: #{output_path}"
    puts "=" * 60
  end
end
