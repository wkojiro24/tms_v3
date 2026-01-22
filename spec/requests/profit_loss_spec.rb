# frozen_string_literal: true

require "rails_helper"

RSpec.describe "ProfitLoss", type: :request do
  let(:tenant) { @tenant }
  let(:import_batch) { @import_batch }

  before(:each) do
    @tenant = Tenant.create!(name: "Test Tenant", slug: "test-pl-#{SecureRandom.hex(4)}", time_zone: "Asia/Tokyo")
    ActsAsTenant.current_tenant = @tenant

    @import_batch = ImportBatch.create!(
      tenant: @tenant,
      source_file_name: "test.xlsx",
      source_digest: "abc123",
      imported_at: Time.current
    )

    SummarySetting.find_or_create_by!(tenant: @tenant) do |s|
      s.term_start_month = 9
    end
  end

  after(:each) do
    ActsAsTenant.current_tenant = nil
  end

  describe "GET /profit_loss/drilldown" do
    let!(:journal_entry) do
      JournalEntry.create!(
        tenant: tenant,
        import_batch: import_batch,
        entry_date: Date.new(2025, 1, 15),
        slip_no: "TEST001",
        summary: "軽油代"
      )
    end

    let!(:debit_line) do
      JournalLine.create!(
        journal_entry: journal_entry,
        side: "debit",
        account_name: "[製]軽油費",
        sub_account_name: nil,
        amount: 100_000
      )
    end

    let!(:credit_line) do
      JournalLine.create!(
        journal_entry: journal_entry,
        side: "credit",
        account_name: "買掛金",
        sub_account_name: "太陽鉱油㈱",
        amount: 100_000
      )
    end

    context "drilldownクエリのテスト" do
      it "勘定科目でLIKE検索できる" do
        lines = JournalLine.joins(:journal_entry)
                           .where(journal_entries: { entry_date: Date.new(2025, 1, 1)..Date.new(2025, 1, 31) })
                           .where("journal_lines.account_name LIKE ?", "%軽油費%")

        expect(lines.count).to eq(1)
        expect(lines.first.account_name).to eq("[製]軽油費")
      end

      it "相手勘定から補助科目（取引先名）を取得できる" do
        line = debit_line
        counter_line = line.journal_entry.journal_lines.find do |l|
          l.id != line.id && l.sub_account_name.present?
        end

        expect(counter_line).not_to be_nil
        expect(counter_line.sub_account_name).to eq("太陽鉱油㈱")
      end
    end
  end

  describe "drilldownコントローラーロジック" do
    let!(:journal_entry) do
      JournalEntry.create!(
        tenant: tenant,
        import_batch: import_batch,
        entry_date: Date.new(2025, 1, 15),
        slip_no: "TEST002",
        summary: "軽油代"
      )
    end

    let!(:debit_line) do
      JournalLine.create!(
        journal_entry: journal_entry,
        side: "debit",
        account_name: "[製]軽油費",
        sub_account_name: nil,
        amount: 200_000
      )
    end

    let!(:credit_line) do
      JournalLine.create!(
        journal_entry: journal_entry,
        side: "credit",
        account_name: "買掛金",
        sub_account_name: "エネオス㈱",
        amount: 200_000
      )
    end

    it "vendor_namesハッシュに相手勘定の補助科目をマッピングする" do
      account_name = "軽油費"
      period_start = Date.new(2025, 1, 1)
      period_end = Date.new(2025, 1, 31)

      journal_lines = JournalLine.joins(:journal_entry)
                                 .where(journal_entries: { entry_date: period_start..period_end })
                                 .where("journal_lines.account_name LIKE ?", "%#{account_name}%")
                                 .includes(journal_entry: :journal_lines)

      vendor_names = {}
      journal_lines.each do |line|
        next if line.sub_account_name.present?

        counter_line = line.journal_entry.journal_lines.find do |l|
          l.id != line.id && l.sub_account_name.present?
        end

        if counter_line&.sub_account_name.present?
          vendor_names[line.id] = counter_line.sub_account_name
        end
      end

      expect(vendor_names[debit_line.id]).to eq("エネオス㈱")
    end

    it "借方・貸方の合計を計算する" do
      account_name = "軽油費"
      period_start = Date.new(2025, 1, 1)
      period_end = Date.new(2025, 1, 31)

      journal_lines = JournalLine.joins(:journal_entry)
                                 .where(journal_entries: { entry_date: period_start..period_end })
                                 .where("journal_lines.account_name LIKE ?", "%#{account_name}%")

      totals = {
        debit: journal_lines.where(side: "debit").sum(:amount),
        credit: journal_lines.where(side: "credit").sum(:amount)
      }

      expect(totals[:debit]).to eq(200_000)
      expect(totals[:credit]).to eq(0)
    end
  end
end
