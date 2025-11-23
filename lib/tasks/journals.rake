require "digest"

namespace :journals do
  desc "Import normalized journal rows from an Excel workbook. Usage: rails journals:import[path/to/file.xlsx]"
  task :import, [:file_path] => :environment do |_t, args|
    file_path = args[:file_path] || ENV["FILE"]
    abort "Specify file path (rails journals:import[path/to/file.xlsx])" if file_path.blank?

    tenant = Tenant.find_by!(slug: ENV.fetch("TENANT", "default"))
    digest = Digest::SHA256.file(file_path).hexdigest
    batch_metadata = {
      period_start: ENV["PERIOD_START"],
      period_end: ENV["PERIOD_END"]
    }.compact
    replace_flag = ENV.fetch("REPLACE", "true").to_s.downcase
    replace_period = %w[true 1 yes y].include?(replace_flag)

    ActsAsTenant.with_tenant(tenant) do
      importer = Imports::JournalImporter.new(
        tenant: tenant,
        file_path: file_path,
        source_file_name: File.basename(file_path),
        options: {
          source_digest: digest,
          metadata: batch_metadata,
          period_start: ENV["PERIOD_START"],
          period_end: ENV["PERIOD_END"],
          replace_period: replace_period
        }
      )
      batch = importer.call
      puts "[journals:import] batch=#{batch.id} entries=#{batch.journal_entries.count} lines=#{batch.journal_entries.sum { |entry| entry.journal_lines.size }}"
    end
  end

  desc "Classify journals with fixed/variable/split nature by rules"
  task classify: :environment do
    puts "[journals:classify] skipped (journal classifier not yet implemented for journal_lines)"
  end

  desc "Resolve vehicle IDs from memo/vendor strings using vehicle aliases"
  task resolve_vehicle: :environment do
    puts "[journals:resolve_vehicle] skipped (vehicle resolver not yet implemented for journal_lines)"
  end
end
