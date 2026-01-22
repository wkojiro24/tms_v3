namespace :vehicle_financials do
  desc "Import all vehicle financial files from data/vehicle_financials directory"
  task import_all: :environment do
    base_dir = Rails.root.join("data", "vehicle_financials")

    unless base_dir.exist?
      puts "Error: Directory not found: #{base_dir}"
      exit 1
    end

    tenant = Tenant.first
    unless tenant
      puts "Error: No tenant found"
      exit 1
    end

    puts "=== Vehicle Financial Import ==="
    puts "Tenant: #{tenant.name}"
    puts "Base directory: #{base_dir}"
    puts

    # 期ごとのフォルダを取得（62期〜76期）
    term_dirs = base_dir.children.select(&:directory?).sort_by { |d| d.basename.to_s }

    total_files = 0
    total_records = 0
    errors = []

    ActsAsTenant.with_tenant(tenant) do
      term_dirs.each do |term_dir|
        term_name = term_dir.basename.to_s
        puts "Processing #{term_name}..."

        # xlsm/xlsx ファイルを取得
        files = term_dir.glob("*.{xlsm,xlsx}").sort

        if files.empty?
          puts "  No Excel files found"
          next
        end

        files.each do |file_path|
          begin
            importer = VehicleFinancialImporter.new(path: file_path, tenant: tenant)
            count = importer.import!
            total_files += 1
            total_records += count
            puts "  #{file_path.basename}: #{count} records"
          rescue => e
            error_msg = "  #{file_path.basename}: ERROR - #{e.message}"
            puts error_msg
            errors << { file: file_path.to_s, error: e.message }
          end
        end
      end
    end

    puts
    puts "=== Import Complete ==="
    puts "Files processed: #{total_files}"
    puts "Total records: #{total_records}"

    if errors.any?
      puts
      puts "=== Errors (#{errors.size}) ==="
      errors.each do |err|
        puts "  #{err[:file]}: #{err[:error]}"
      end
    end

    # cell_state の統計を表示
    puts
    puts "=== Cell State Statistics ==="
    ActsAsTenant.with_tenant(tenant) do
      VehicleFinancialMetric.group(:cell_state).count.each do |state, count|
        puts "  #{state}: #{count}"
      end
    end
  end

  desc "Detect duplicate vehicle codes in vehicle_financial_metrics"
  task detect_duplicates: :environment do
    tenant = Tenant.first
    unless tenant
      puts "Error: No tenant found"
      exit 1
    end

    puts "=== Vehicle Code Duplicate Detection ==="
    puts "Tenant: #{tenant.name}"
    puts

    ActsAsTenant.with_tenant(tenant) do
      detector = VehicleDuplicateDetector.new(tenant)
      report = detector.generate_report

      puts "Total unique codes: #{report[:total_unique_codes]}"
      puts "Duplicate groups: #{report[:duplicate_groups]}"
      puts "Total duplicate variants: #{report[:total_duplicate_variants]}"
      puts

      if report[:duplicates].any?
        puts "=== Duplicate Groups ==="
        report[:duplicates].each do |dup|
          vehicle_status = dup[:vehicle_exists] ? "✓" : "✗"
          puts "  #{dup[:normalized]} [#{vehicle_status}]: #{dup[:variants].join(', ')}"
        end
      else
        puts "No duplicates found."
      end
    end
  end

  desc "Resolve duplicate vehicle codes (dry run by default, use EXECUTE=true to apply)"
  task resolve_duplicates: :environment do
    tenant = Tenant.first
    unless tenant
      puts "Error: No tenant found"
      exit 1
    end

    dry_run = ENV["EXECUTE"] != "true"

    puts "=== Vehicle Code Duplicate Resolution ==="
    puts "Tenant: #{tenant.name}"
    puts "Mode: #{dry_run ? 'DRY RUN (no changes will be made)' : 'EXECUTE (changes will be applied)'}"
    puts

    ActsAsTenant.with_tenant(tenant) do
      detector = VehicleDuplicateDetector.new(tenant)
      results = detector.resolve_duplicates!(dry_run: dry_run)

      if dry_run
        puts "Would update: #{results[:skipped]} records"
      else
        puts "Updated: #{results[:updated]} records"
      end

      puts
      puts "=== Details ==="
      results[:details].each do |detail|
        puts "  #{detail[:from]} → #{detail[:to]} (#{detail[:count]} records) [#{detail[:action]}]"
      end

      if dry_run && results[:details].any?
        puts
        puts "To apply these changes, run: rake vehicle_financials:resolve_duplicates EXECUTE=true"
      end
    end
  end

  desc "Import vehicle financial files for a specific term (e.g., rake vehicle_financials:import_term[75期])"
  task :import_term, [:term] => :environment do |_t, args|
    term = args[:term]
    unless term
      puts "Error: Please specify a term, e.g., rake vehicle_financials:import_term[75期]"
      exit 1
    end

    term_dir = Rails.root.join("data", "vehicle_financials", term)
    unless term_dir.exist?
      puts "Error: Directory not found: #{term_dir}"
      exit 1
    end

    tenant = Tenant.first
    unless tenant
      puts "Error: No tenant found"
      exit 1
    end

    puts "=== Importing #{term} ==="
    files = term_dir.glob("*.{xlsm,xlsx}").sort

    ActsAsTenant.with_tenant(tenant) do
      files.each do |file_path|
        begin
          importer = VehicleFinancialImporter.new(path: file_path, tenant: tenant)
          count = importer.import!
          puts "  #{file_path.basename}: #{count} records"
        rescue => e
          puts "  #{file_path.basename}: ERROR - #{e.message}"
        end
      end
    end
  end
end
