namespace :pl do
  desc "Rebuild PL snapshots for YYYY-MM (single) or FROM,TO (inclusive). Usage: rails pl:snapshot[2024-09]"
  task :snapshot, [:period_from, :period_to] => :environment do |_t, args|
    period_from = args[:period_from] || ENV["PERIOD"]
    abort "Specify period (YYYY-MM)" if period_from.blank?

    from_month = Date.parse("#{period_from}-01").beginning_of_month
    to_arg = args[:period_to] || ENV["PERIOD_TO"] || period_from
    to_month = Date.parse("#{to_arg}-01").beginning_of_month

    tenant = Tenant.find_by!(slug: ENV.fetch("TENANT", "default"))
    periods = []
    current_month = from_month
    while current_month <= to_month
      periods << current_month
      current_month = current_month.next_month
    end

    ActsAsTenant.with_tenant(tenant) do
      Pl::SnapshotBuilder.new(
        tenant: tenant,
        periods: periods,
        options: { replace: ActiveModel::Type::Boolean.new.cast(ENV["REPLACE"]) }
      ).call
      puts "[pl:snapshot] rebuilt #{periods.count} periods for tenant=#{tenant.slug}"
    end
  end
end
