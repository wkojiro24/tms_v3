# 車両番号の名寄せを行うサービス
#
# ⚠️ 重要: 末尾の英字サフィックス（A, B, C等）は絶対に削除しない
# 100 と 100A は別の車両として扱う
#
# @example 基本変換
#   normalizer = VehicleNormalizer.new(tenant)
#   normalizer.normalize("100番")     #=> "100"
#   normalizer.normalize("100A番")    #=> "100A"  ← Aは保持
#   normalizer.normalize("品川100A")  #=> "100A"  ← Aは保持
#
# @example 先頭ゼロ削除
#   normalizer.normalize("00100")     #=> "100"
#   normalizer.normalize("0017")      #=> "17"
#   normalizer.normalize("00100A")    #=> "100A"  ← サフィックス保持
#
# @example ハイフン正規化
#   normalizer.normalize("1825－6070") #=> "1825-6070" ← 全角→半角
#   normalizer.normalize("0139-8828")  #=> "139-8828"  ← 先頭ゼロ削除
#
# @example 大文字化
#   normalizer.normalize("a1246")     #=> "A1246"
#   normalizer.normalize("100a")      #=> "100A"
#
class VehicleNormalizer
  # 日本の地名パターン（車両番号に含まれる可能性のあるもの）
  PREFECTURE_PATTERNS = %w[
    品川 練馬 足立 多摩 八王子 横浜 川崎 相模 湘南
    名古屋 三河 豊橋 岡崎 一宮 尾張小牧 春日井
    大阪 なにわ 和泉 堺 京都 神戸 姫路
    札幌 函館 旭川 室蘭 帯広 釧路 北見
    仙台 福島 郡山 いわき 水戸 つくば 土浦 宇都宮
    群馬 前橋 高崎 大宮 川越 熊谷 所沢 春日部 越谷
    千葉 成田 柏 習志野 野田 袖ケ浦
    富山 金沢 福井 長野 松本 諏訪 山梨
    岐阜 静岡 浜松 沼津 三島
    滋賀 奈良 和歌山 鳥取 島根 岡山 倉敷 広島 福山 山口
    徳島 香川 愛媛 高知
    北九州 福岡 久留米 筑豊 佐賀 長崎 佐世保 熊本 大分 宮崎 鹿児島 沖縄
  ].freeze

  # 削除対象のサフィックス（「番」「号」など）
  # 注意: 英字サフィックス(A, B, C等)は削除しない
  REMOVABLE_SUFFIXES = %w[番 号 車].freeze

  # 集計用の特殊コード（名寄せ対象外）
  SPECIAL_CODES = %w[66666 66700 77777 88888 99991 99992 99999].freeze

  attr_reader :tenant

  def initialize(tenant = nil)
    @tenant = tenant || ActsAsTenant.current_tenant
    raise ArgumentError, "tenant is required" unless @tenant
  end

  # 車両番号を正規化する
  # @param raw_number [String] 生の車両番号
  # @return [String, nil] 正規化された番号、または変換できない場合はnil
  def normalize(raw_number)
    return nil if raw_number.blank?

    # Step 1: 基本正規化
    cleaned = basic_normalize(raw_number.to_s)

    # Step 2: 正規ナンバーとして存在するか確認
    return cleaned if vehicle_exists?(cleaned)

    # Step 3: エイリアステーブルで検索
    aliased = find_by_alias(cleaned)
    return aliased if aliased.present?

    # Step 4: パターンマッチング（サフィックス保持）
    pattern_matched = apply_patterns(cleaned)
    return pattern_matched if pattern_matched.present? && vehicle_exists?(pattern_matched)

    # Step 5: パターン適用後、エイリアス検索
    aliased_after_pattern = find_by_alias(pattern_matched) if pattern_matched.present?
    return aliased_after_pattern if aliased_after_pattern.present?

    # Step 6: 見つからない場合は未マッピングに記録してパターン適用後の値を返す
    record_unmapped(raw_number, pattern_matched || cleaned)
    pattern_matched || cleaned
  end

  # 車両オブジェクトを取得する
  # @param raw_number [String] 生の車両番号
  # @return [Vehicle, nil]
  def find_vehicle(raw_number)
    normalized = normalize(raw_number)
    return nil if normalized.blank?

    find_vehicle_by_code(normalized)
  end

  # 正規化結果の詳細を取得する（デバッグ/ログ用）
  # @param raw_number [String] 生の車両番号
  # @return [Hash]
  def normalize_with_details(raw_number)
    return { raw: raw_number, normalized: nil, method: :blank } if raw_number.blank?

    cleaned = basic_normalize(raw_number.to_s)

    # 正規ナンバーとして存在
    if vehicle_exists?(cleaned)
      return { raw: raw_number, normalized: cleaned, method: :direct }
    end

    # エイリアス検索
    aliased = find_by_alias(cleaned)
    if aliased.present?
      return { raw: raw_number, normalized: aliased, method: :alias }
    end

    # パターンマッチング
    pattern_matched = apply_patterns(cleaned)
    if pattern_matched.present? && vehicle_exists?(pattern_matched)
      return { raw: raw_number, normalized: pattern_matched, method: :pattern }
    end

    # パターン後にエイリアス
    aliased_after_pattern = find_by_alias(pattern_matched) if pattern_matched.present?
    if aliased_after_pattern.present?
      return { raw: raw_number, normalized: aliased_after_pattern, method: :alias_after_pattern }
    end

    # 見つからない
    {
      raw: raw_number,
      normalized: pattern_matched || cleaned,
      method: :unmapped,
      vehicle_found: false
    }
  end

  private

  # --- Step 1: 基本正規化 ---

  def basic_normalize(str)
    result = str.dup

    # 前後の空白削除
    result.strip!

    # シングルクォート・バッククォートを削除（Excel文字列形式: '0070）
    result = result.delete("'`")

    # 全角数字→半角数字
    result = result.tr("０-９", "0-9")

    # 全角英字→半角英字
    result = result.tr("Ａ-Ｚａ-ｚ", "A-Za-z")

    # 小文字→大文字（a1246 → A1246）
    result = result.upcase

    # 全角ハイフン・ダッシュ類→半角ハイフン
    result = normalize_hyphens(result)

    # 内部の空白削除
    result.gsub!(/\s+/, "")

    # 小数点以下の.0を削除（Excel数値形式: 1116.0 → 1116）
    result = remove_trailing_decimal_zero(result)

    # 先頭ゼロの正規化（ハイフン付き番号は各部分で処理）
    result = normalize_leading_zeros(result)

    result
  end

  # 末尾の.0を削除（Excel数値形式対応）
  # 例: "1116.0" → "1116", "401500139.0" → "401500139"
  def remove_trailing_decimal_zero(str)
    # 数字.0 の形式のみ対応（小数点以下が0のみの場合）
    str.sub(/\.0+\z/, "")
  end

  # ハイフン類の正規化
  def normalize_hyphens(str)
    # 全角ハイフン、ダッシュ、長音符などを半角ハイフンに統一
    str.gsub(/[－—–―ー−]/, "-")
  end

  # 先頭ゼロの正規化
  # 例: "00100" → "100", "0017" → "17"
  # ハイフン付き: "0139-8828" → "139-8828", "4015-00139" → "4015-139"
  def normalize_leading_zeros(str)
    if str.include?("-")
      # ハイフン付き番号は各部分を個別に処理
      str.split("-").map { |part| strip_leading_zeros(part) }.join("-")
    else
      strip_leading_zeros(str)
    end
  end

  # 数字部分の先頭ゼロを削除（英字サフィックスは保持）
  def strip_leading_zeros(str)
    # 数字のみ、または数字+英字のパターン
    if str.match?(/^\d+[A-Z]*$/)
      # 数字部分の先頭ゼロを削除
      str.sub(/^0+(?=\d)/, "")
    else
      str
    end
  end

  # --- Step 2: 車両存在確認 ---

  def vehicle_exists?(code)
    return false if code.blank?

    find_vehicle_by_code(code).present?
  end

  def find_vehicle_by_code(code)
    Vehicle.find_by(tenant_id: tenant.id, registration_number: code) ||
      Vehicle.find_by(tenant_id: tenant.id, call_sign: code)
  end

  # --- Step 3: エイリアス検索 ---

  def find_by_alias(code)
    return nil if code.blank?

    # 完全一致を優先
    exact_alias = VehicleAlias.find_by(
      tenant_id: tenant.id,
      pattern: code,
      pattern_type: "exact",
      active: true
    )
    return exact_alias.vehicle_id if exact_alias.present?

    # 正規表現マッチング
    regex_aliases = VehicleAlias.where(
      tenant_id: tenant.id,
      pattern_type: "regex",
      active: true
    )

    regex_aliases.each do |alias_record|
      begin
        regex = Regexp.new(alias_record.pattern)
        return alias_record.vehicle_id if code.match?(regex)
      rescue RegexpError
        # 無効な正規表現はスキップ
        Rails.logger.warn "Invalid regex pattern in vehicle_aliases: #{alias_record.pattern}"
      end
    end

    nil
  end

  # --- Step 4: パターンマッチング ---

  def apply_patterns(str)
    result = str.dup

    # 地名を削除
    PREFECTURE_PATTERNS.each do |prefecture|
      result = result.gsub(/^#{Regexp.escape(prefecture)}/, "")
    end

    # 「番」「号」「車」を削除（ただし英字サフィックスは保持）
    # 例: "100番" → "100", "100A番" → "100A"
    result = remove_japanese_suffixes(result)

    # 空になった場合は元の値を返す
    result.blank? ? str : result
  end

  # 日本語サフィックスを削除しつつ、英字サフィックスは保持する
  # ⚠️ 最重要ロジック: 100 と 100A は別車両
  def remove_japanese_suffixes(str)
    # パターン: 数字 + オプションの日本語サフィックス + オプションの英字サフィックス(1-2文字) + 日本語サフィックス
    # 例: "100番" → "100", "100A番" → "100A", "100AB号" → "100AB", "100号A" → "100A"

    result = str.dup

    # まず末尾の日本語サフィックスを削除
    REMOVABLE_SUFFIXES.each do |suffix|
      if result.end_with?(suffix)
        result = result.chomp(suffix)
      end
    end

    # 「100号A」のような中間にある日本語サフィックスを削除
    # パターン: 数字 + 日本語サフィックス + 英字 → 数字 + 英字
    REMOVABLE_SUFFIXES.each do |suffix|
      # 数字の後に日本語サフィックス、その後に英字が続くパターン
      result = result.gsub(/(\d+)#{Regexp.escape(suffix)}([A-Za-z]+)$/, '\1\2')
    end

    str = result

    # 数字の後に続く英字サフィックスは保持（すでにsuffixを削除済みなのでそのまま）
    # 検証: 数字+英字のパターンになっているか確認
    # 例: "100A", "200BC" など

    str
  end

  # --- Step 5: 未マッピング記録 ---

  def record_unmapped(raw_number, cleaned_number)
    UnmappedVehicleNumber.record_unmapped(raw_number, cleaned_number)
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "Failed to record unmapped vehicle number: #{e.message}"
  end
end
