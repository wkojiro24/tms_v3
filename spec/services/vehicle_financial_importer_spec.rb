require "rails_helper"

class FakeSheet
  def initialize(rows)
    @rows = rows
  end

  def row(index)
    @rows[index - 1] || []
  end

  def cell(row_index, column_index)
    row(row_index)[column_index - 1]
  end

  def last_row
    @rows.length
  end
end

RSpec.describe VehicleFinancialImporter do
  let!(:tenant) { Tenant.create!(name: "Test Tenant", slug: "test", time_zone: "Asia/Tokyo") }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  it "imports metrics for valid vehicle codes while skipping excluded ones" do
    rows = [
      ["2025年7月", nil, nil],
      ["車番", nil, "100", "9999"],
      ["輸送収入", nil, 1_200_000, 500_000],
      ["車両費", "減価償却費", 220_000, 80_000],
      ["年式", nil, "平成24年8月", "令和元年5月"],
      ["損益", nil, 600_000, 200_000],
      ["東京営業所", nil, 999]
    ]

    fake_sheet = FakeSheet.new(rows)
    spreadsheet = instance_double(Roo::Excelx)
    allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet)
    allow(spreadsheet).to receive(:sheet).with(0).and_return(fake_sheet)

    fake_tmp = Rails.root.join("tmp/dummy.xlsx")
    FileUtils.touch(fake_tmp)

    importer = described_class.new(path: fake_tmp, tenant: tenant, exclude_codes: %w[9999])

    expect { importer.import! }.to change(VehicleFinancialMetric, :count).by(4)

    metric = VehicleFinancialMetric.find_by(metric_label: "輸送収入")
    expect(metric.month).to eq(Date.new(2025, 7, 1))
    expect(metric.value_numeric).to eq(BigDecimal("1200000"))
    expect(metric.vehicle_code).to eq("100")
    expect(metric.source_file).to eq("dummy.xlsx")

    depreciation = VehicleFinancialMetric.find_by(metric_label: "減価償却費")
    expect(depreciation.metadata["section_label"]).to eq("車両費")
    expect(VehicleFinancialMetric.exists?(metric_label: "東京営業所")).to be false

    model_year = VehicleFinancialMetric.find_by(metric_label: "年式")
    expect(model_year.value_numeric).to be_nil
    expect(model_year.value_text).to eq("平成24年8月")

    profit = VehicleFinancialMetric.find_by(metric_label: "損益")
    expect(profit.value_numeric).to eq(BigDecimal("600000"))
  ensure
    FileUtils.rm_f(fake_tmp)
  end
end

RSpec.describe VehicleFinancialImporter, "vehicle normalization" do
  let!(:tenant) { Tenant.create!(name: "Test Tenant", slug: "norm", time_zone: "Asia/Tokyo") }

  before do
    ActsAsTenant.current_tenant = tenant
  end

  after do
    ActsAsTenant.current_tenant = nil
  end

  it "normalizes vehicle codes with leading zeros" do
    rows = [
      ["2025年7月", nil, nil, nil],
      ["車番", nil, "00100", "0017"],
      ["輸送収入", nil, 1_200_000, 800_000],
      ["損益", nil, 600_000, 400_000]
    ]

    fake_sheet = FakeSheet.new(rows)
    spreadsheet = instance_double(Roo::Excelx)
    allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet)
    allow(spreadsheet).to receive(:sheet).with(0).and_return(fake_sheet)

    fake_tmp = Rails.root.join("tmp/norm_test.xlsx")
    FileUtils.touch(fake_tmp)

    importer = described_class.new(path: fake_tmp, tenant: tenant)
    importer.import!

    # 先頭ゼロが削除されて保存されている
    expect(VehicleFinancialMetric.exists?(vehicle_code: "100")).to be true
    expect(VehicleFinancialMetric.exists?(vehicle_code: "17")).to be true
    expect(VehicleFinancialMetric.exists?(vehicle_code: "00100")).to be false
    expect(VehicleFinancialMetric.exists?(vehicle_code: "0017")).to be false

    # metadataに元のコードが記録されている
    metric = VehicleFinancialMetric.find_by(vehicle_code: "100", metric_label: "輸送収入")
    expect(metric.metadata["raw_vehicle_code"]).to eq("00100")
  ensure
    FileUtils.rm_f(fake_tmp)
  end

  it "normalizes full-width hyphens to half-width" do
    rows = [
      ["2025年7月", nil, nil],
      ["車番", nil, "1825－6070"],
      ["輸送収入", nil, 1_000_000],
      ["損益", nil, 500_000]
    ]

    fake_sheet = FakeSheet.new(rows)
    spreadsheet = instance_double(Roo::Excelx)
    allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet)
    allow(spreadsheet).to receive(:sheet).with(0).and_return(fake_sheet)

    fake_tmp = Rails.root.join("tmp/hyphen_test.xlsx")
    FileUtils.touch(fake_tmp)

    importer = described_class.new(path: fake_tmp, tenant: tenant)
    importer.import!

    # 全角ハイフンが半角に変換されている
    expect(VehicleFinancialMetric.exists?(vehicle_code: "1825-6070")).to be true
    expect(VehicleFinancialMetric.exists?(vehicle_code: "1825－6070")).to be false
  ensure
    FileUtils.rm_f(fake_tmp)
  end

  it "preserves English letter suffixes during normalization" do
    rows = [
      ["2025年7月", nil, nil, nil],
      ["車番", nil, "100A", "200B"],
      ["輸送収入", nil, 1_200_000, 800_000],
      ["損益", nil, 600_000, 400_000]
    ]

    fake_sheet = FakeSheet.new(rows)
    spreadsheet = instance_double(Roo::Excelx)
    allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet)
    allow(spreadsheet).to receive(:sheet).with(0).and_return(fake_sheet)

    fake_tmp = Rails.root.join("tmp/suffix_test.xlsx")
    FileUtils.touch(fake_tmp)

    importer = described_class.new(path: fake_tmp, tenant: tenant)
    importer.import!

    # 英字サフィックスが保持されている
    expect(VehicleFinancialMetric.exists?(vehicle_code: "100A")).to be true
    expect(VehicleFinancialMetric.exists?(vehicle_code: "200B")).to be true
  ensure
    FileUtils.rm_f(fake_tmp)
  end

  it "links to existing vehicle when normalized code matches" do
    vehicle = Vehicle.create!(tenant: tenant, registration_number: "100")

    rows = [
      ["2025年7月", nil, nil],
      ["車番", nil, "00100"],
      ["輸送収入", nil, 1_200_000],
      ["損益", nil, 600_000]
    ]

    fake_sheet = FakeSheet.new(rows)
    spreadsheet = instance_double(Roo::Excelx)
    allow(Roo::Spreadsheet).to receive(:open).and_return(spreadsheet)
    allow(spreadsheet).to receive(:sheet).with(0).and_return(fake_sheet)

    fake_tmp = Rails.root.join("tmp/link_test.xlsx")
    FileUtils.touch(fake_tmp)

    importer = described_class.new(path: fake_tmp, tenant: tenant)
    importer.import!

    # 正規化後のコードで車両がリンクされている
    metric = VehicleFinancialMetric.find_by(vehicle_code: "100")
    expect(metric.vehicle_id).to eq(vehicle.id)
  ensure
    FileUtils.rm_f(fake_tmp)
  end
end

RSpec.describe VehicleFinancialImporter, "helper methods" do
  let!(:tenant) { Tenant.create!(name: "Test Tenant", slug: "helper", time_zone: "Asia/Tokyo") }
  let(:tmp_file) { Rails.root.join("tmp/helper.xlsx") }
  let(:importer) { described_class.new(path: tmp_file, tenant: tenant) }

  before { FileUtils.touch(tmp_file) }
  after { FileUtils.rm_f(tmp_file) }

  it "parses month strings with dot separator" do
    expect(importer.send(:parse_month_from_string, "2024.8")).to eq(Date.new(2024, 8, 1))
  end

  it "parses month strings with slash separator" do
    expect(importer.send(:parse_month_from_string, "2024/09")).to eq(Date.new(2024, 9, 1))
  end

  it "does not treat kanji mixed strings as numeric" do
    expect(importer.send(:parse_numeric, "平成24年8月")).to be_nil
  end

  it "detects month from filename when header is missing" do
    file = Rails.root.join("tmp", "原価計算2508.xls")
    FileUtils.touch(file)
    helper_importer = described_class.new(path: file, tenant: tenant)
    expect(helper_importer.send(:month_from_filename)).to eq(Date.new(2025, 8, 1))
  ensure
    FileUtils.rm_f(file)
  end

  it "extracts detail labels when present" do
    sheet = FakeSheet.new([
      ["2025年7月"],
      ["車番", nil, "100"],
      ["車両費", "減価償却費", 100]
    ])

    labels = importer.send(:extract_row_labels, sheet, 3)
    expect(labels[:label]).to eq("減価償却費")
    expect(labels[:section_label]).to eq("車両費")
  end
end
