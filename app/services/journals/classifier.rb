module Journals
  class Classifier
    attr_reader :tenant, :relation

    def initialize(tenant:, relation: nil)
      @tenant = tenant
      @relation = relation
    end

    def call
      timestamp = Time.zone.now
      target.find_each do |journal|
        rule = matching_rule_for(journal)
        next unless rule

        journal.update!(
          nature: rule.nature,
          metadata: journal.metadata.merge("classification_rule_id" => rule.id),
          processed_at: timestamp
        )
      end
    end

    private

    def target
      relation || tenant.journals
    end

    def rules
      @rules ||= tenant.classification_rules.active.order(:priority)
    end

    def matching_rule_for(journal)
      rules.detect { |rule| matches_rule?(journal, rule) }
    end

    def matches_rule?(journal, rule)
      return false if rule.conditions.blank?

      rule.conditions.all? do |key, expected|
        actual_values = Array(fetch_value(journal, key))
        next false if actual_values.blank?

        match_condition?(actual_values, expected, key)
      end
    end

    def fetch_value(journal, key)
      case key.to_s
      when "account_code"
        [journal.debit_ac_code, journal.credit_ac_code].compact
      when "account_name"
        [journal.debit_ac_name, journal.credit_ac_name].compact
      when "vendor_name"
        [journal.vendor_name, journal.metadata["credit_vendor_name"]].compact
      when "memo_keyword"
        journal.memo
      when "dept_code"
        journal.dept_code
      when "dept_name"
        [journal.dept_name, journal.metadata["credit_dept_name"]].compact
      else
        journal.metadata[key.to_s]
      end
    end

    def match_condition?(actual_values, expected, key)
      expected_values = Array(expected).compact
      return false if expected_values.blank?

      matcher = matcher_for(key)

      expected_values.any? do |expected_value|
        actual_values.any? { |actual| matcher.call(actual, expected_value) }
      end
    end

    def matcher_for(key)
      case key.to_s
      when "account_code", "dept_code"
        ->(actual, expected) { actual.to_s == expected.to_s }
      when "memo_keyword"
        ->(actual, expected) { actual.to_s.downcase.include?(expected.to_s.downcase) }
      else
        ->(actual, expected) { actual.to_s.downcase.include?(expected.to_s.downcase) }
      end
    end
  end
end
