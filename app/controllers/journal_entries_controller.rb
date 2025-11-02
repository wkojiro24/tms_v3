class JournalEntriesController < ApplicationController
  before_action :authenticate_user!

  FISCAL_YEAR_START_MONTH = 9

  def index
    @years = available_fiscal_years

    if @years.blank?
      @entries = []
      @month_tabs = []
      @selected_year = nil
      @selected_month = nil
      @limit = entries_limit
      @query = ""
      @fiscal_year_label = ""
      @period_start = nil
      @period_end = nil
      return
    end

    @selected_year = normalize_year(params[:year])
    @selected_month = normalize_month(params[:month])
    @limit = entries_limit
    @query = params[:query].to_s.strip

    fiscal_range = fiscal_year_range(@selected_year)
    @fiscal_year_label = "#{@selected_year}年度（#{fiscal_range.first.strftime('%Y/%m')}〜#{fiscal_range.last.strftime('%Y/%m')}）"

    months_with_data = months_with_data_for(@selected_year)
    @month_tabs = fiscal_months.map do |month|
      {
        month: month,
        label: "#{month}月",
        active: month == @selected_month,
        has_data: months_with_data.include?(month),
        path: journal_entries_path(year: @selected_year, month:, query: @query.presence, limit: @limit)
      }
    end

    actual_year_for_month = actual_year(@selected_year, @selected_month)

    period_start = Date.new(actual_year_for_month, @selected_month, 1)
    period_end = period_start.end_of_month

    entries = JournalEntry.includes(:journal_lines)
                          .where(entry_date: period_start..period_end)

    if @query.present?
      q = "%#{@query}%"
      entries = entries.left_outer_joins(:journal_lines).where(
        "journal_entries.summary ILIKE :q OR journal_entries.slip_no ILIKE :q OR journal_lines.account_name ILIKE :q OR journal_lines.sub_account_name ILIKE :q OR journal_lines.vendor_name ILIKE :q OR journal_lines.memo ILIKE :q",
        q: q
      )
    end

    entries_scope = entries.distinct
    @available_entry_count = entries_scope.count

    ordered_scope = entries_scope.order(entry_date: :asc, slip_no: :asc)
    @entries = ordered_scope.limit(@limit)
    @limited = @available_entry_count > @entries.size

    @period_start = period_start
    @period_end = period_end
    @prev_params = navigation_params(period_start.prev_month)
    @next_params = navigation_params(period_start.next_month)

    @entry_rows = build_entry_rows(@entries)
  end

  private

  def available_fiscal_years
    JournalEntry
      .distinct
      .pluck(:entry_date)
      .map { |date| fiscal_year_for(date) }
      .uniq
      .sort
      .reverse
  end

  def months_with_data_for(year)
    JournalEntry
      .where(entry_date: fiscal_year_range(year))
      .pluck(Arel.sql("DISTINCT EXTRACT(MONTH FROM entry_date)::int"))
      .map(&:to_i)
  end

  def normalize_year(param_year)
    year = param_year.present? ? param_year.to_i : @years.first
    @years.include?(year) ? year : @years.first
  end

  def normalize_month(param_month)
    month_value = param_month.present? ? param_month.to_i : nil
    month_value = fiscal_months.include?(month_value) ? month_value : nil
    return month_value if month_value

    available = months_with_data_for(@selected_year)
    (fiscal_months & available).first || fiscal_months.first
  end

  def entries_limit
    limit = params[:limit].present? ? params[:limit].to_i : 1000
    limit = 1000 if limit <= 0
    [[limit, 5000].min, 50].max
  end

  def build_entry_rows(entries)
    entries.map do |entry|
      grouped_rows = build_grouped_rows(entry)
      {
        entry: entry,
        rows: grouped_rows
      }
    end
  end

  def fiscal_months
    @fiscal_months ||= (FISCAL_YEAR_START_MONTH..12).to_a + (1..FISCAL_YEAR_START_MONTH - 1).to_a
  end

  def fiscal_year_for(date)
    date.month >= FISCAL_YEAR_START_MONTH ? date.year : date.year - 1
  end

  def fiscal_year_range(year)
    start_date = Date.new(year, FISCAL_YEAR_START_MONTH, 1)
    end_date = Date.new(year + 1, FISCAL_YEAR_START_MONTH - 1, 1).end_of_month
    start_date..end_date
  end

  def actual_year(fiscal_year, month)
    month >= FISCAL_YEAR_START_MONTH ? fiscal_year : fiscal_year + 1
  end

  def navigation_params(target_date)
    {
      year: fiscal_year_for(target_date),
      month: target_date.month,
      query: @query.presence,
      limit: @limit
    }
  end

  def build_grouped_rows(entry)
    grouped = entry.journal_lines.group_by do |line|
      line.source_row_number || :"line-#{line.id}"
    end

    sorted_keys = grouped.keys.sort_by do |key|
      key.is_a?(Integer) ? key : Float::INFINITY
    end

    rows = []
    sorted_keys.each do |key|
      lines = grouped[key]
      debit_lines = lines.select { |line| line.side == "debit" }
      credit_lines = lines.select { |line| line.side == "credit" }
      max_rows = [debit_lines.size, credit_lines.size, 1].max

      max_rows.times do |index|
        rows << {
          debit: debit_lines[index],
          credit: credit_lines[index]
        }
      end
    end

    rows
  end
end
