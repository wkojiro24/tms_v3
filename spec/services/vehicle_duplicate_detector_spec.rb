require "rails_helper"

RSpec.describe VehicleDuplicateDetector do
  let!(:tenant) { Tenant.create!(name: "Test Tenant", slug: "dup-test", time_zone: "Asia/Tokyo") }
  let(:detector) { described_class.new(tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "#detect_duplicates" do
    it "先頭ゼロの違いによる重複を検出する" do
      codes = %w[100 00100 0100]

      duplicates = detector.detect_duplicates(codes)

      expect(duplicates.size).to eq(1)
      expect(duplicates.first[:normalized]).to eq("100")
      expect(duplicates.first[:variants]).to contain_exactly("100", "00100", "0100")
    end

    it "全角・半角ハイフンの違いによる重複を検出する" do
      codes = ["1825-6070", "1825－6070"]

      duplicates = detector.detect_duplicates(codes)

      expect(duplicates.size).to eq(1)
      expect(duplicates.first[:normalized]).to eq("1825-6070")
      expect(duplicates.first[:variants]).to contain_exactly("1825-6070", "1825－6070")
    end

    it "大文字・小文字の違いによる重複を検出する" do
      codes = %w[A1246 a1246]

      duplicates = detector.detect_duplicates(codes)

      expect(duplicates.size).to eq(1)
      expect(duplicates.first[:normalized]).to eq("A1246")
    end

    it "重複がない場合は空配列を返す" do
      codes = %w[100 200 300]

      duplicates = detector.detect_duplicates(codes)

      expect(duplicates).to be_empty
    end

    it "英字サフィックスは別車両として扱う（重複ではない）" do
      codes = %w[100 100A 100B]

      duplicates = detector.detect_duplicates(codes)

      expect(duplicates).to be_empty
    end

    it "複合的な重複パターンを検出する" do
      codes = %w[00100 0100 100 0017 17 1825-6070]
      codes << "1825－6070"

      duplicates = detector.detect_duplicates(codes)

      expect(duplicates.size).to eq(3)

      dup_100 = duplicates.find { |d| d[:normalized] == "100" }
      expect(dup_100[:variants]).to contain_exactly("00100", "0100", "100")

      dup_17 = duplicates.find { |d| d[:normalized] == "17" }
      expect(dup_17[:variants]).to contain_exactly("0017", "17")

      dup_hyphen = duplicates.find { |d| d[:normalized] == "1825-6070" }
      expect(dup_hyphen[:variants]).to contain_exactly("1825-6070", "1825－6070")
    end
  end

  describe "#detect_from_metrics" do
    it "vehicle_financial_metricsテーブルから重複を検出する" do
      # テストデータを作成
      VehicleFinancialMetric.create!(
        tenant: tenant,
        vehicle_code: "00100",
        month: Date.new(2025, 1, 1),
        metric_key: "revenue",
        metric_label: "輸送収入",
        value_numeric: 1000
      )
      VehicleFinancialMetric.create!(
        tenant: tenant,
        vehicle_code: "100",
        month: Date.new(2025, 2, 1),
        metric_key: "revenue",
        metric_label: "輸送収入",
        value_numeric: 1200
      )
      VehicleFinancialMetric.create!(
        tenant: tenant,
        vehicle_code: "200",
        month: Date.new(2025, 1, 1),
        metric_key: "revenue",
        metric_label: "輸送収入",
        value_numeric: 800
      )

      duplicates = detector.detect_from_metrics

      expect(duplicates.size).to eq(1)
      expect(duplicates.first[:normalized]).to eq("100")
      expect(duplicates.first[:variants]).to contain_exactly("00100", "100")
    end
  end

  describe "#generate_report" do
    it "重複レポートを生成する" do
      VehicleFinancialMetric.create!(
        tenant: tenant,
        vehicle_code: "00100",
        month: Date.new(2025, 1, 1),
        metric_key: "revenue",
        metric_label: "輸送収入",
        value_numeric: 1000
      )
      VehicleFinancialMetric.create!(
        tenant: tenant,
        vehicle_code: "100",
        month: Date.new(2025, 2, 1),
        metric_key: "revenue",
        metric_label: "輸送収入",
        value_numeric: 1200
      )

      report = detector.generate_report

      expect(report[:total_unique_codes]).to eq(2)
      expect(report[:duplicate_groups]).to eq(1)
      expect(report[:total_duplicate_variants]).to eq(2)
      expect(report[:duplicates]).to be_present
      expect(report[:generated_at]).to be_present
    end
  end

  describe "#resolve_duplicates!" do
    before do
      VehicleFinancialMetric.create!(
        tenant: tenant,
        vehicle_code: "00100",
        month: Date.new(2025, 1, 1),
        metric_key: "revenue",
        metric_label: "輸送収入",
        value_numeric: 1000
      )
      VehicleFinancialMetric.create!(
        tenant: tenant,
        vehicle_code: "0100",
        month: Date.new(2025, 2, 1),
        metric_key: "revenue",
        metric_label: "輸送収入",
        value_numeric: 1200
      )
    end

    context "dry_run: true (デフォルト)" do
      it "実際の更新は行わない" do
        results = detector.resolve_duplicates!(dry_run: true)

        expect(results[:updated]).to eq(0)
        expect(results[:skipped]).to eq(2)

        # データは変更されていない
        expect(VehicleFinancialMetric.exists?(vehicle_code: "00100")).to be true
        expect(VehicleFinancialMetric.exists?(vehicle_code: "0100")).to be true
      end
    end

    context "dry_run: false" do
      it "重複を正規化された値に更新する" do
        results = detector.resolve_duplicates!(dry_run: false)

        expect(results[:updated]).to eq(2)

        # 全て正規化された値に更新されている
        expect(VehicleFinancialMetric.exists?(vehicle_code: "00100")).to be false
        expect(VehicleFinancialMetric.exists?(vehicle_code: "0100")).to be false
        expect(VehicleFinancialMetric.where(vehicle_code: "100").count).to eq(2)
      end
    end
  end

  describe "初期化" do
    it "tenantなしで初期化するとArgumentErrorが発生する" do
      ActsAsTenant.current_tenant = nil
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end
end
