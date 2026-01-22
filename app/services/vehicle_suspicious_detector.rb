# 疑わしい車両コードの重複候補を検出するサービス
#
# 自動正規化では対応できないが、人間が見れば「同じ車両では？」と
# 思われるパターンを検出してレコメンドする
#
# @example
#   detector = VehicleSuspiciousDetector.new(tenant)
#   candidates = detector.detect_all
#   # => [
#   #      { type: :missing_hyphen, code1: "18625846", code2: "1862-5846", confidence: :high },
#   #      { type: :similar_digits, code1: "1136", code2: "11360", confidence: :medium }
#   #    ]
#
class VehicleSuspiciousDetector
  attr_reader :tenant

  # 信頼度レベル
  CONFIDENCE_LEVELS = %i[high medium low].freeze

  def initialize(tenant = nil)
    @tenant = tenant || ActsAsTenant.current_tenant
    raise ArgumentError, "tenant is required" unless @tenant
  end

  # 全ての疑わしい重複候補を検出
  # @return [Array<Hash>] 候補の配列
  def detect_all
    codes = fetch_all_codes
    candidates = []

    candidates.concat(detect_missing_hyphens(codes))
    candidates.concat(detect_similar_digits(codes))
    candidates.concat(detect_sequential_periods(codes))

    # 無視リストを除外
    ignored_pairs = fetch_ignored_pairs

    # 重複を除去して信頼度順にソート
    candidates
      .uniq { |c| [c[:code1], c[:code2]].sort }
      .reject { |c| ignored_pairs.include?([c[:code1], c[:code2]].sort) }
      .sort_by { |c| [CONFIDENCE_LEVELS.index(c[:confidence]), c[:code1]] }
  end

  # 無視リストを取得
  def fetch_ignored_pairs
    setting = SummarySetting.find_by(tenant_id: tenant.id)
    return [] unless setting

    ignored = setting.label_mappings&.dig("_ignored_suspicious_pairs") || []
    ignored.map { |pair| pair.sort }
  end

  # 無視リストに追加
  def self.add_to_ignore_list(tenant:, code1:, code2:)
    setting = SummarySetting.for(tenant)
    mappings = setting.label_mappings || {}
    ignored = mappings["_ignored_suspicious_pairs"] || []
    ignored << [code1, code2].sort
    mappings["_ignored_suspicious_pairs"] = ignored.uniq
    setting.update!(label_mappings: mappings)
  end

  # ハイフン抜けパターンを検出
  # 例: "18625846" と "1862-5846"
  def detect_missing_hyphens(codes)
    candidates = []
    hyphenated = codes.select { |c| c.include?("-") }
    non_hyphenated = codes.reject { |c| c.include?("-") }

    hyphenated.each do |h_code|
      # ハイフンを除去した形式
      without_hyphen = h_code.delete("-")

      non_hyphenated.each do |nh_code|
        if nh_code == without_hyphen
          candidates << build_candidate(
            type: :missing_hyphen,
            code1: nh_code,
            code2: h_code,
            confidence: :high,
            reason: "「#{nh_code}」は「#{h_code}」のハイフン抜けの可能性"
          )
        end
      end
    end

    candidates
  end

  # 類似数字パターンを検出
  # 例: "1136" と "11360"（末尾に0追加）
  def detect_similar_digits(codes)
    candidates = []
    numeric_codes = codes.select { |c| c.match?(/^\d+$/) }

    numeric_codes.combination(2).each do |code1, code2|
      # 長い方と短い方を判定
      short, long = [code1, code2].sort_by(&:length)
      next if short.length == long.length

      # パターン1: 末尾に0が追加されている（例: 1136 → 11360）
      if long == "#{short}0"
        candidates << build_candidate(
          type: :trailing_zero,
          code1: short,
          code2: long,
          confidence: :medium,
          reason: "「#{long}」は「#{short}」に末尾0が追加された可能性"
        )
      end

      # パターン2: 先頭に数字が追加されている（例: 136 → 1136）
      if long.end_with?(short) && long.length == short.length + 1
        candidates << build_candidate(
          type: :leading_digit,
          code1: short,
          code2: long,
          confidence: :low,
          reason: "「#{long}」は「#{short}」に先頭数字が追加された可能性"
        )
      end
    end

    candidates
  end

  # 連続する期間パターンを検出
  # 例: コードAの最終月 → コードBの開始月が連続している
  def detect_sequential_periods(codes)
    candidates = []

    # 各コードの期間を取得
    code_periods = codes.each_with_object({}) do |code, hash|
      months = VehicleFinancialMetric
        .where(tenant_id: tenant.id, vehicle_code: code)
        .distinct.pluck(:month).sort
      hash[code] = { first: months.first, last: months.last, count: months.size } if months.any?
    end

    # 類似コード間で連続性をチェック
    codes.combination(2).each do |code1, code2|
      period1 = code_periods[code1]
      period2 = code_periods[code2]
      next unless period1 && period2

      # コードが類似しているかチェック（編集距離など）
      next unless similar_codes?(code1, code2)

      # 期間が連続しているかチェック
      if sequential_months?(period1[:last], period2[:first])
        candidates << build_candidate(
          type: :sequential_period,
          code1: code1,
          code2: code2,
          confidence: :medium,
          reason: "「#{code1}」(〜#{period1[:last]&.strftime('%Y-%m')}) と「#{code2}」(#{period2[:first]&.strftime('%Y-%m')}〜) の期間が連続",
          metadata: {
            code1_period: "#{period1[:first]&.strftime('%Y-%m')}〜#{period1[:last]&.strftime('%Y-%m')}",
            code2_period: "#{period2[:first]&.strftime('%Y-%m')}〜#{period2[:last]&.strftime('%Y-%m')}"
          }
        )
      elsif sequential_months?(period2[:last], period1[:first])
        candidates << build_candidate(
          type: :sequential_period,
          code1: code2,
          code2: code1,
          confidence: :medium,
          reason: "「#{code2}」(〜#{period2[:last]&.strftime('%Y-%m')}) と「#{code1}」(#{period1[:first]&.strftime('%Y-%m')}〜) の期間が連続",
          metadata: {
            code1_period: "#{period2[:first]&.strftime('%Y-%m')}〜#{period2[:last]&.strftime('%Y-%m')}",
            code2_period: "#{period1[:first]&.strftime('%Y-%m')}〜#{period1[:last]&.strftime('%Y-%m')}"
          }
        )
      end
    end

    candidates
  end

  # 候補をマージ（エイリアス登録 + データ更新）
  # @param from_code [String] マージ元コード（消える方）
  # @param to_code [String] マージ先コード（残る方）
  # @param dry_run [Boolean] trueの場合は実行せずにプレビューのみ
  def merge_codes!(from_code:, to_code:, dry_run: true)
    result = {
      from: from_code,
      to: to_code,
      records_to_update: 0,
      alias_created: false,
      dry_run: dry_run
    }

    ActsAsTenant.with_tenant(tenant) do
      # 更新対象レコード数
      result[:records_to_update] = VehicleFinancialMetric
        .where(vehicle_code: from_code)
        .count

      unless dry_run
        # エイリアス登録
        alias_record = VehicleAlias.find_or_initialize_by(
          tenant: tenant,
          pattern: from_code,
          pattern_type: "exact"
        )
        alias_record.vehicle_id = to_code
        alias_record.active = true
        alias_record.save!
        result[:alias_created] = true

        # データ更新
        VehicleFinancialMetric
          .where(vehicle_code: from_code)
          .update_all(vehicle_code: to_code)
      end
    end

    result
  end

  private

  def fetch_all_codes
    VehicleFinancialMetric
      .where(tenant_id: tenant.id)
      .distinct
      .pluck(:vehicle_code)
      .compact
  end

  def build_candidate(type:, code1:, code2:, confidence:, reason:, metadata: {})
    {
      type: type,
      code1: code1,
      code2: code2,
      confidence: confidence,
      reason: reason,
      metadata: metadata
    }
  end

  # 2つのコードが類似しているか判定
  def similar_codes?(code1, code2)
    # レーベンシュタイン距離が2以下
    levenshtein_distance(code1, code2) <= 2
  end

  # 月が連続しているか判定（1ヶ月以内の差）
  def sequential_months?(month1, month2)
    return false unless month1 && month2

    diff = (month2.year * 12 + month2.month) - (month1.year * 12 + month1.month)
    diff >= 1 && diff <= 2  # 1-2ヶ月の差は連続とみなす
  end

  # レーベンシュタイン距離を計算
  def levenshtein_distance(s1, s2)
    m = s1.length
    n = s2.length

    return n if m.zero?
    return m if n.zero?

    d = Array.new(m + 1) { Array.new(n + 1, 0) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }

    (1..m).each do |i|
      (1..n).each do |j|
        cost = s1[i - 1] == s2[j - 1] ? 0 : 1
        d[i][j] = [
          d[i - 1][j] + 1,      # 削除
          d[i][j - 1] + 1,      # 挿入
          d[i - 1][j - 1] + cost # 置換
        ].min
      end
    end

    d[m][n]
  end
end
