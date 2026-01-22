# 車両番号の重複を検出するサービス
#
# VehicleNormalizerで正規化した結果、同じコードになる車両を検出する
#
# @example
#   detector = VehicleDuplicateDetector.new(tenant)
#   duplicates = detector.detect_all
#   # => [
#   #      { normalized: "100", variants: ["00100", "100", "0100"] },
#   #      { normalized: "1825-6070", variants: ["1825-6070", "1825－6070"] }
#   #    ]
#
class VehicleDuplicateDetector
  attr_reader :tenant, :normalizer

  def initialize(tenant = nil)
    @tenant = tenant || ActsAsTenant.current_tenant
    raise ArgumentError, "tenant is required" unless @tenant

    @normalizer = VehicleNormalizer.new(@tenant)
  end

  # vehicle_financial_metricsテーブルから重複を検出
  # @return [Array<Hash>] 重複グループの配列
  def detect_from_metrics
    # 全てのユニークな車両コードを取得
    raw_codes = VehicleFinancialMetric
      .where(tenant_id: tenant.id)
      .distinct
      .pluck(:vehicle_code)

    detect_duplicates(raw_codes)
  end

  # 任意のコード配列から重複を検出
  # @param codes [Array<String>] 車両コードの配列
  # @return [Array<Hash>] 重複グループの配列
  def detect_duplicates(codes)
    # 正規化してグループ化
    normalized_groups = codes.each_with_object(Hash.new { |h, k| h[k] = [] }) do |code, groups|
      next if code.blank?

      normalized = normalizer.normalize(code)
      groups[normalized] << code if normalized.present?
    end

    # 2つ以上のバリエーションがあるものを抽出
    duplicates = normalized_groups.select { |_, variants| variants.uniq.size > 1 }

    duplicates.map do |normalized, variants|
      {
        normalized: normalized,
        variants: variants.uniq.sort,
        count: variants.size,
        vehicle_exists: normalizer.find_vehicle(normalized).present?
      }
    end.sort_by { |d| -d[:count] }
  end

  # 重複検出レポートを生成
  # @return [Hash] レポート
  def generate_report
    duplicates = detect_from_metrics

    {
      total_unique_codes: VehicleFinancialMetric.where(tenant_id: tenant.id).distinct.count(:vehicle_code),
      duplicate_groups: duplicates.size,
      total_duplicate_variants: duplicates.sum { |d| d[:variants].size },
      duplicates: duplicates,
      generated_at: Time.current
    }
  end

  # 重複をログに出力
  def log_duplicates
    duplicates = detect_from_metrics

    if duplicates.empty?
      Rails.logger.info "[VehicleDuplicateDetector] 重複なし"
      return
    end

    Rails.logger.warn "[VehicleDuplicateDetector] #{duplicates.size}件の重複グループを検出"

    duplicates.each do |dup|
      vehicle_status = dup[:vehicle_exists] ? "車両あり" : "車両なし"
      Rails.logger.warn "[VehicleDuplicateDetector] #{dup[:normalized]} (#{vehicle_status}): #{dup[:variants].join(', ')}"
    end
  end

  # 重複を自動解決（vehicle_codeを正規化された値に更新）
  # @param dry_run [Boolean] trueの場合は実際の更新を行わない
  # @return [Hash] 更新結果
  def resolve_duplicates!(dry_run: true)
    duplicates = detect_from_metrics
    results = { updated: 0, skipped: 0, details: [] }

    duplicates.each do |dup|
      normalized = dup[:normalized]

      dup[:variants].each do |variant|
        next if variant == normalized # 既に正規化済み

        count = VehicleFinancialMetric
          .where(tenant_id: tenant.id, vehicle_code: variant)
          .count

        if dry_run
          results[:details] << {
            from: variant,
            to: normalized,
            count: count,
            action: "would_update"
          }
          results[:skipped] += count
        else
          VehicleFinancialMetric
            .where(tenant_id: tenant.id, vehicle_code: variant)
            .update_all(vehicle_code: normalized)

          results[:details] << {
            from: variant,
            to: normalized,
            count: count,
            action: "updated"
          }
          results[:updated] += count
        end
      end
    end

    results
  end
end
