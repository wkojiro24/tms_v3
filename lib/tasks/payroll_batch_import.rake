module PayrollBatchImportHelpers
  def self.extract_year_month(dirname)
    # Patterns: "2024.01", "2024.1月分", "2024.12月分"
    if dirname =~ /(\d{4})\.?(\d{1,2})月?分?/
      [$1.to_i, $2.to_i]
    elsif dirname =~ /(\d{4})\.(\d{1,2})/
      [$1.to_i, $2.to_i]
    else
      [nil, nil]
    end
  end

  def self.extract_location(filename)
    # Extract location from filename like "2024.1月分給与支給控除一覧表　東京.xlsx"
    locations = %w[東京 川崎 仙台 小名浜 九州 本社]
    locations.each do |loc|
      return loc if filename.include?(loc)
    end
    "default"
  end
end

namespace :payroll do
  desc "Batch import payroll files for specified years"
  task :batch_import, [:years] => :environment do |_t, args|
    years = args[:years]&.split(",")&.map(&:to_i) || [2024, 2025]
    base_dir = Rails.root.join("data/salary")

    # Find the first admin user
    admin_user = User.find_by(role: "admin") || User.first
    unless admin_user
      puts "Error: No user found to assign as uploader"
      exit 1
    end

    tenant = Tenant.first
    unless tenant
      puts "Error: No tenant found"
      exit 1
    end

    total_imported = 0
    total_errors = 0

    ActsAsTenant.with_tenant(tenant) do
      # Collect all month directories across all year folders
      all_months = []

      years.each do |folder_year|
        year_dir = base_dir.join(folder_year.to_s)
        next unless year_dir.exist?

        Dir.glob(year_dir.join("*")).sort.each do |month_dir|
          next unless File.directory?(month_dir)
          month_name = File.basename(month_dir)
          next if month_name.include?("賞与")

          data_year, month = PayrollBatchImportHelpers.extract_year_month(month_name)
          next unless data_year && month

          # Only import if the data year is in our target years
          next unless years.include?(data_year)

          all_months << { dir: month_dir, year: data_year, month: month, name: month_name }
        end
      end

      # Sort by year and month
      all_months.sort_by! { |m| [m[:year], m[:month]] }

      all_months.each do |month_data|
        puts "\n--- #{month_data[:year]}/#{month_data[:month].to_s.rjust(2, '0')} ---"

        Dir.glob(File.join(month_data[:dir], "*.xlsx")).each do |file_path|
          next if File.basename(file_path).start_with?("._")

          filename = File.basename(file_path)
          location = PayrollBatchImportHelpers.extract_location(filename)

          puts "  Importing: #{filename} (location: #{location})"

          begin
            File.open(file_path, "rb") do |io|
              importer = Imports::PayrollImporter.new(
                io,
                uploaded_by: admin_user,
                location: location,
                expected_period: Date.new(month_data[:year], month_data[:month], 1),
                period_mode: :auto
              )
              result = importer.call

              if result.errors.any?
                puts "    ERROR: #{result.errors.map { |e| e[:message] }.join(', ')}"
                total_errors += 1
              else
                puts "    OK: created=#{result.created}, updated=#{result.updated}, skipped=#{result.skipped}"
                total_imported += 1
              end
            end
          rescue => e
            puts "    EXCEPTION: #{e.message}"
            total_errors += 1
          end
        end
      end
    end

    puts "\n=== Summary ==="
    puts "Total imported: #{total_imported}"
    puts "Total errors: #{total_errors}"
  end
end
