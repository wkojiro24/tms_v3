module Journals
  class VehicleResolver
    attr_reader :tenant, :relation

    def initialize(tenant:, relation: nil)
      @tenant = tenant
      @relation = relation
    end

    def call
      target.find_each do |journal|
        vehicle_id = resolve_vehicle_id(journal)
        next unless vehicle_id

        journal.update!(vehicle_id: vehicle_id)
      end
    end

    private

    def target
      relation || tenant.journals.where(vehicle_id: nil)
    end

    def resolve_vehicle_id(journal)
      candidates = candidate_strings_for(journal)

      vehicle_aliases.detect do |vehicle_alias|
        match_alias?(vehicle_alias, candidates)
      end&.vehicle_id
    end

    def candidate_strings_for(journal)
      [
        journal.vehicle_hint,
        journal.memo,
        journal.vendor_name,
        journal.metadata["credit_vendor_name"]
      ].compact.map { |value| value.to_s }
    end

    def vehicle_aliases
      @vehicle_aliases ||= tenant.vehicle_aliases.where(active: true)
    end

    def match_alias?(vehicle_alias, candidates)
      case vehicle_alias.pattern_type
      when "regex"
        pattern = Regexp.new(vehicle_alias.pattern)
        candidates.any? { |candidate| pattern.match?(candidate) }
      else
        normalized_pattern = vehicle_alias.pattern.to_s
        candidates.any? { |candidate| candidate.include?(normalized_pattern) }
      end
    rescue RegexpError
      false
    end
  end
end
