require "rails_helper"

RSpec.describe VehicleNormalizer do
  let(:tenant) { Tenant.first || Tenant.create!(name: "Test Tenant", slug: "test-#{SecureRandom.hex(4)}") }
  let(:normalizer) { described_class.new(tenant) }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  describe "#normalize" do
    context "基本的な正規化" do
      # テナント内に車両が存在しない場合でもパターン変換は行われる
      it "既に正規形式の番号はそのまま返す" do
        expect(normalizer.normalize("100")).to eq("100")
      end

      it "「番」を削除する" do
        expect(normalizer.normalize("100番")).to eq("100")
      end

      it "地名を削除する" do
        expect(normalizer.normalize("品川100")).to eq("100")
      end

      it "全角数字を半角に変換する" do
        expect(normalizer.normalize("１００")).to eq("100")
      end

      it "末尾の空白を削除する" do
        expect(normalizer.normalize("100 ")).to eq("100")
      end

      it "先頭の空白を削除する" do
        expect(normalizer.normalize(" 100")).to eq("100")
      end

      it "内部の空白を削除する" do
        expect(normalizer.normalize("1 0 0")).to eq("100")
      end

      it "「号」を削除する" do
        expect(normalizer.normalize("100号")).to eq("100")
      end

      it "複合パターン: 地名+番号+「番」" do
        expect(normalizer.normalize("品川100番")).to eq("100")
      end
    end

    # ⚠️ 最重要: サフィックス保持テスト
    context "英字サフィックスの保持（最重要）" do
      it "「100A」はそのまま「100A」を返す" do
        result = normalizer.normalize("100A")
        expect(result).to eq("100A")
      end

      it "「100A番」は「100A」を返す（「番」削除、「A」保持）" do
        result = normalizer.normalize("100A番")
        expect(result).to eq("100A")
      end

      it "「品川100A」は「100A」を返す（地名削除、「A」保持）" do
        result = normalizer.normalize("品川100A")
        expect(result).to eq("100A")
      end

      it "「１００Ａ」は「100A」を返す（全角→半角、「A」保持）" do
        result = normalizer.normalize("１００Ａ")
        expect(result).to eq("100A")
      end

      it "「100 A」は「100A」を返す（空白削除、「A」保持）" do
        result = normalizer.normalize("100 A")
        expect(result).to eq("100A")
      end

      it "「100AB」は「100AB」を返す（2文字サフィックス保持）" do
        result = normalizer.normalize("100AB")
        expect(result).to eq("100AB")
      end

      it "「100号A」は「100A」を返す（「号」削除、「A」保持）" do
        result = normalizer.normalize("100号A")
        expect(result).to eq("100A")
      end

      it "「品川100A番」は「100A」を返す" do
        result = normalizer.normalize("品川100A番")
        expect(result).to eq("100A")
      end

      it "「１００Ａ番」は「100A」を返す" do
        result = normalizer.normalize("１００Ａ番")
        expect(result).to eq("100A")
      end

      # 100 と 100A は別車両であることの確認
      it "「100」と「100A」は異なる結果を返す" do
        result_100 = normalizer.normalize("100番")
        result_100a = normalizer.normalize("100A番")

        expect(result_100).to eq("100")
        expect(result_100a).to eq("100A")
        expect(result_100).not_to eq(result_100a)
      end
    end

    context "車両が存在する場合" do
      let!(:vehicle_100) { Vehicle.create!(tenant: tenant, registration_number: "100") }
      let!(:vehicle_100a) { Vehicle.create!(tenant: tenant, registration_number: "100A") }
      let!(:vehicle_200) { Vehicle.create!(tenant: tenant, registration_number: "200") }

      it "存在する車両の番号に正規化される" do
        expect(normalizer.normalize("100番")).to eq("100")
        expect(normalizer.normalize("100A番")).to eq("100A")
        expect(normalizer.normalize("品川200")).to eq("200")
      end

      it "100番と100A番は別の車両として認識される" do
        vehicle_100_found = normalizer.find_vehicle("100番")
        vehicle_100a_found = normalizer.find_vehicle("100A番")

        expect(vehicle_100_found).to eq(vehicle_100)
        expect(vehicle_100a_found).to eq(vehicle_100a)
        expect(vehicle_100_found).not_to eq(vehicle_100a_found)
      end
    end

    context "エイリアスが存在する場合" do
      let!(:vehicle_100) { Vehicle.create!(tenant: tenant, registration_number: "100") }

      before do
        VehicleAlias.create!(
          tenant: tenant,
          pattern: "百番",
          pattern_type: "exact",
          vehicle_id: "100",
          active: true
        )
      end

      it "エイリアスに登録されたパターンは正規番号に変換される" do
        expect(normalizer.normalize("百番")).to eq("100")
      end
    end

    context "正規表現エイリアスの場合" do
      let!(:vehicle_100) { Vehicle.create!(tenant: tenant, registration_number: "100") }

      before do
        # 大文字に正規化されるので、パターンも大文字で
        VehicleAlias.create!(
          tenant: tenant,
          pattern: "^NO\\.?(\\d+)$",
          pattern_type: "regex",
          vehicle_id: "100",
          active: true
        )
      end

      it "正規表現にマッチする場合は変換される" do
        # 入力は "No.100" だが、基本正規化で "NO.100" に変換される
        expect(normalizer.normalize("No.100")).to eq("100")
        expect(normalizer.normalize("NO100")).to eq("100")
      end
    end

    context "未マッピング番号の記録" do
      it "見つからない番号はUnmappedVehicleNumberに記録される" do
        expect {
          normalizer.normalize("999")
        }.to change(UnmappedVehicleNumber, :count).by(1)

        unmapped = UnmappedVehicleNumber.find_by(raw_number: "999")
        expect(unmapped).to be_present
        expect(unmapped.cleaned_number).to eq("999")
        expect(unmapped.occurrence_count).to eq(1)
        expect(unmapped.resolved).to be false
      end

      it "同じ番号が複数回来た場合はoccurrence_countが増加する" do
        normalizer.normalize("999")
        normalizer.normalize("999")
        normalizer.normalize("999")

        unmapped = UnmappedVehicleNumber.find_by(raw_number: "999")
        expect(unmapped.occurrence_count).to eq(3)
      end
    end

    context "先頭ゼロの正規化" do
      it "「00100」は「100」に正規化される" do
        expect(normalizer.normalize("00100")).to eq("100")
      end

      it "「0017」は「17」に正規化される" do
        expect(normalizer.normalize("0017")).to eq("17")
      end

      it "「00139」は「139」に正規化される" do
        expect(normalizer.normalize("00139")).to eq("139")
      end

      it "「0」は「0」のまま（全てゼロは保持）" do
        expect(normalizer.normalize("0")).to eq("0")
      end

      it "「00100A」は「100A」に正規化される（サフィックス保持）" do
        expect(normalizer.normalize("00100A")).to eq("100A")
      end
    end

    context "ハイフン付き番号の正規化" do
      it "「1825-6070」はそのまま" do
        expect(normalizer.normalize("1825-6070")).to eq("1825-6070")
      end

      it "「1825－6070」（全角ハイフン）は「1825-6070」に正規化" do
        expect(normalizer.normalize("1825－6070")).to eq("1825-6070")
      end

      it "「0139-8828」は「139-8828」に正規化（先頭ゼロ削除）" do
        expect(normalizer.normalize("0139-8828")).to eq("139-8828")
      end

      it "「4015-00139」は「4015-139」に正規化" do
        expect(normalizer.normalize("4015-00139")).to eq("4015-139")
      end

      it "各種ダッシュ記号を半角ハイフンに統一" do
        # 全角ハイフン（－）
        expect(normalizer.normalize("100－200")).to eq("100-200")
        # EMダッシュ（—）
        expect(normalizer.normalize("100—200")).to eq("100-200")
        # ENダッシュ（–）
        expect(normalizer.normalize("100–200")).to eq("100-200")
      end
    end

    context "大文字小文字の正規化" do
      it "「a1246」は「A1246」に正規化（大文字化）" do
        expect(normalizer.normalize("a1246")).to eq("A1246")
      end

      it "「100a」は「100A」に正規化" do
        expect(normalizer.normalize("100a")).to eq("100A")
      end

      it "「abc」は「ABC」に正規化" do
        expect(normalizer.normalize("abc")).to eq("ABC")
      end

      it "混在ケース「100aB」は「100AB」に正規化" do
        expect(normalizer.normalize("100aB")).to eq("100AB")
      end
    end

    context "Excel数値形式の正規化" do
      it "「1116.0」は「1116」に正規化される" do
        expect(normalizer.normalize("1116.0")).to eq("1116")
      end

      it "「1827.0」は「1827」に正規化される" do
        expect(normalizer.normalize("1827.0")).to eq("1827")
      end

      it "「2602.0」は「2602」に正規化される" do
        expect(normalizer.normalize("2602.0")).to eq("2602")
      end

      it "小数点以下が0以外の場合はそのまま" do
        expect(normalizer.normalize("100.5")).to eq("100.5")
      end
    end

    context "シングルクォートの削除" do
      it "「'0070」は「70」に正規化される（クォート削除+先頭ゼロ削除）" do
        expect(normalizer.normalize("'0070")).to eq("70")
      end

      it "「5174-'0070」は「5174-70」に正規化される" do
        expect(normalizer.normalize("5174-'0070")).to eq("5174-70")
      end

      it "バッククォートも削除される" do
        expect(normalizer.normalize("`0100")).to eq("100")
      end
    end

    context "エッジケース" do
      it "nilの場合はnilを返す" do
        expect(normalizer.normalize(nil)).to be_nil
      end

      it "空文字の場合はnilを返す" do
        expect(normalizer.normalize("")).to be_nil
      end

      it "空白のみの場合はnilを返す" do
        expect(normalizer.normalize("   ")).to be_nil
      end

      it "数字を含まない場合もそのまま処理する" do
        result = normalizer.normalize("ABC")
        expect(result).to eq("ABC")
      end
    end

    context "様々な地名パターン" do
      %w[品川 練馬 足立 多摩 横浜 名古屋 大阪 なにわ 札幌 仙台 福岡].each do |prefecture|
        it "「#{prefecture}100」は「100」に変換される" do
          expect(normalizer.normalize("#{prefecture}100")).to eq("100")
        end

        it "「#{prefecture}100A」は「100A」に変換される（サフィックス保持）" do
          expect(normalizer.normalize("#{prefecture}100A")).to eq("100A")
        end
      end
    end
  end

  describe "#find_vehicle" do
    let!(:vehicle) { Vehicle.create!(tenant: tenant, registration_number: "100") }

    it "正規化して車両を検索する" do
      expect(normalizer.find_vehicle("100番")).to eq(vehicle)
      expect(normalizer.find_vehicle("品川100")).to eq(vehicle)
      expect(normalizer.find_vehicle("１００")).to eq(vehicle)
    end

    it "call_signでも検索できる" do
      vehicle.update!(call_sign: "車両A")
      found = normalizer.find_vehicle("車両A")
      expect(found).to eq(vehicle)
    end

    it "見つからない場合はnilを返す" do
      expect(normalizer.find_vehicle("999")).to be_nil
    end
  end

  describe "#normalize_with_details" do
    let!(:vehicle) { Vehicle.create!(tenant: tenant, registration_number: "100") }

    it "正規化の詳細情報を返す" do
      result = normalizer.normalize_with_details("100番")

      expect(result[:raw]).to eq("100番")
      expect(result[:normalized]).to eq("100")
      expect(result[:method]).to eq(:pattern)
    end

    it "エイリアス経由の場合はmethodが:aliasになる" do
      VehicleAlias.create!(
        tenant: tenant,
        pattern: "百番",
        pattern_type: "exact",
        vehicle_id: "100",
        active: true
      )

      result = normalizer.normalize_with_details("百番")
      expect(result[:method]).to eq(:alias)
    end

    it "見つからない場合はmethodが:unmappedになる" do
      result = normalizer.normalize_with_details("999")
      expect(result[:method]).to eq(:unmapped)
    end
  end

  describe "初期化" do
    it "tenantなしで初期化するとArgumentErrorが発生する" do
      ActsAsTenant.current_tenant = nil
      expect { described_class.new(nil) }.to raise_error(ArgumentError)
    end
  end
end
