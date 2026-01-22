namespace :vehicles do
  desc "Import vehicle financial metrics from an Excel file. Usage: bin/rails vehicles:import_financials[path/to/file.xlsm]"
  task :import_financials, [:path] => :environment do |_t, args|
    file_path = args[:path] || ENV["FILE"]
    unless file_path
      puts "Please provide a file path via rake argument or FILE env, e.g. bin/rails vehicles:import_financials[data/vehicle_financials/原価計算2508.xlsm]"
      exit 1
    end

    tenant = Tenant.first
    importer = VehicleFinancialImporter.new(path: file_path, tenant: tenant)
    count = importer.import!
    puts "Imported #{count} metric rows from #{file_path}"
  end

  desc "Recursively import all Excel files under a directory"
  task :import_financials_batch, [:directory] => :environment do |_t, args|
    directory = args[:directory] || ENV["DIR"] || "data/vehicle_financials"
    tenant = Tenant.first
    files = Dir.glob(File.join(directory, "**", "原価計算*.{xls,xlsx,xlsm}"))
    if files.empty?
      puts "No financial files found under #{directory}"
      next
    end

    ActsAsTenant.with_tenant(tenant) do
      files.sort.each do |file|
        begin
          importer = VehicleFinancialImporter.new(path: file, tenant: tenant)
          count = importer.import!
          puts "✔ Imported #{count} rows from #{file}"
        rescue StandardError => e
          warn "✖ Failed to import #{file}: #{e.message}"
        end
      end
    end
  end
end
