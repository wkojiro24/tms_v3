module Pl
  class SnapshotBuilder
    attr_reader :tenant, :periods, :options

    def initialize(tenant:, periods:, options: {})
      @tenant = tenant
      @periods = Array(periods).map { |period| period.to_date.beginning_of_month }.uniq
      @options = options
    end

    def call
      periods.each { |period| rebuild_period(period) }
    end

    private

    def rebuild_period(period)
      Snapshot.where(tenant:, period_month: period).delete_all if replace?

      aggregated = Hash.new do |hash, key|
        hash[key] = {
          actual_amount: 0,
          fixed_amount: 0,
          variable_amount: 0,
          unknown_amount: 0,
          managed_amount: 0
        }
      end

      journal_scope(period).find_each do |line|
        mapping = mapping_for(line)
        next unless mapping

        scope_type, scope_key = scope_for(line, mapping)
        summary = aggregated[[mapping.pl_tree_node_id, scope_type, scope_key]]

        amount = line.amount.to_i
        summary[:actual_amount] += amount
        summary[:managed_amount] += managed_amount_for(line)

        nature = nature_for(line)
        case nature
        when "fixed"
          summary[:fixed_amount] += amount
        when "variable"
          summary[:variable_amount] += amount
        else
          summary[:unknown_amount] += amount
        end
      end

      persist(period, aggregated)
    end

    def replace?
      options.fetch(:replace, false)
    end

    def journal_scope(period)
      JournalLine
        .includes(:journal_entry)
        .where(journal_entries: { tenant_id: tenant.id, entry_date: period..period.end_of_month })
    end

    def mapping_for(line)
      mappings.detect { |mapping| mapping_match?(line, mapping) }
    end

    def mappings
      @mappings ||= tenant.pl_mappings.active.order(:priority)
    end

    def mapping_match?(line, mapping)
      return false if mapping.account_code.present? && !code_matches?(line, mapping.account_code)
      return false if mapping.account_name.present? && !name_matches?(line, mapping.account_name)
      return false if mapping.vendor_name.present? && !vendor_matches?(line, mapping.vendor_name)
      return false if mapping.memo_keyword.present? && !memo_matches?(line, mapping.memo_keyword)
      return false if mapping.dept_code.present? && !dept_code_matches?(line, mapping.dept_code)
      return false if mapping.vehicle_id.present? && line.metadata["vehicle_id"].to_s != mapping.vehicle_id.to_s

      true
    end

    def code_matches?(line, expected)
      line.account_code.to_s == expected.to_s
    end

    def name_matches?(line, expected)
      normalized_expected = expected.to_s.downcase
      [line.account_name, line.sub_account_name].compact.any? { |name| name.to_s.downcase.include?(normalized_expected) }
    end

    def vendor_matches?(line, expected)
      normalized_expected = expected.to_s.downcase
      [line.vendor_name, line.metadata["credit_vendor_name"], line.sub_account_name].compact.any? do |name|
        name.to_s.downcase.include?(normalized_expected)
      end
    end

    def memo_matches?(line, expected)
      memo_sources = [
        line.memo,
        line.metadata["memo"],
        line.journal_entry&.summary
      ]
      memo_sources.compact.any? { |text| text.to_s.downcase.include?(expected.to_s.downcase) }
    end

    def dept_code_matches?(line, expected)
      codes = [line.dept_code, line.metadata["credit_dept_code"]].compact
      codes.any? { |code| code.to_s == expected.to_s }
    end

    def scope_for(line, mapping)
      entry = line.journal_entry
      case mapping.mapping_scope
      when "department"
        dept = line.dept_code.presence ||
               line.dept_name.presence ||
               entry&.metadata&.dig("dept_code") ||
               entry&.metadata&.dig("dept_name") ||
               "unknown"
        ["department", dept]
      when "vehicle"
        vehicle = line.metadata["vehicle_id"].presence ||
                  entry&.metadata&.dig("vehicle_id").presence ||
                  "unknown"
        ["vehicle", vehicle]
      else
        ["company", "company"]
      end
    end

    def managed_amount_for(_line)
      0
    end

    def nature_for(line)
      line.metadata["nature"] || line.journal_entry.metadata["nature"] || "unknown"
    end

    def persist(period, aggregated)
      timestamp = Time.zone.now

      aggregated.each do |(pl_tree_node_id, scope_type, scope_key), amounts|
        Snapshot.upsert(
          {
            tenant_id: tenant.id,
            pl_tree_node_id: pl_tree_node_id,
            period_month: period,
            scope_type: scope_type,
            scope_key: scope_key,
            actual_amount: amounts[:actual_amount],
            managed_amount: amounts[:managed_amount],
            fixed_amount: amounts[:fixed_amount],
            variable_amount: amounts[:variable_amount],
            unknown_amount: amounts[:unknown_amount],
            generated_at: timestamp,
            metadata: {},
            created_at: timestamp,
            updated_at: timestamp
          },
          unique_by: :index_snapshots_on_scope_and_node
        )
      end
    end
  end
end
