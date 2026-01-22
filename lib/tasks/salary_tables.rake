# frozen_string_literal: true

namespace :salary_tables do
  desc "Import grade salary tables from wage regulation (賃金規則)"
  task seed: :environment do
    tenant = Tenant.first
    unless tenant
      puts "No tenant found. Please create a tenant first."
      exit 1
    end

    ActsAsTenant.with_tenant(tenant) do
      # 運転職 能力等級別評価別基本給
      driver_grades = {
        "E" => { "S" => 212_000, "3A" => 207_000, "2A" => 202_000, "A" => 197_000, "B" => 192_000 },
        "H" => { "S" => 202_000, "3A" => 197_000, "2A" => 192_000, "A" => 187_000, "B" => 182_000 },
        "M" => { "S" => 192_000, "3A" => 187_000, "2A" => 182_000, "A" => 177_000, "B" => 175_000 },
        "G" => { "S" => 185_000, "3A" => 180_000, "2A" => 175_000, "A" => 170_000 }
      }

      # 専門職（整備担当）能力等級別評価別基本給
      specialist_grades = {
        "E" => { "S" => 325_000, "3A" => 315_000, "2A" => 305_000, "A" => 295_000, "B" => 285_000 },
        "H" => { "S" => 295_000, "3A" => 285_000, "2A" => 275_000, "A" => 265_000, "B" => 255_000 },
        "M" => { "S" => 255_000, "3A" => 250_000, "2A" => 245_000, "A" => 240_000, "B" => 235_000 },
        "G" => { "S" => 235_000, "3A" => 230_000, "2A" => 225_000, "A" => 220_000, "B" => 215_000 }
      }

      grade_names = {
        "E" => "E級（エキスパート）",
        "H" => "H級（ハイレベル）",
        "M" => "M級（ミドル）",
        "G" => "G級（ジェネラル）"
      }

      evaluation_names = {
        "S" => "S評価",
        "3A" => "3A評価",
        "2A" => "2A評価",
        "A" => "A評価",
        "B" => "B評価"
      }

      created_count = 0
      updated_count = 0

      # 運転職の登録
      driver_grades.each do |grade, evaluations|
        evaluations.each do |eval_code, base_salary|
          grade_code = "運転職-#{grade}-#{eval_code}"
          grade_name = "運転職 #{grade_names[grade]} #{evaluation_names[eval_code]}"

          record = GradeSalaryTable.find_or_initialize_by(grade_code: grade_code)
          is_new = record.new_record?

          record.assign_attributes(
            grade_name: grade_name,
            base_salary: base_salary,
            city_allowance: 0,
            overtime_rate: 1.25,
            late_night_rate: 0.25,
            holiday_rate: 1.35,
            effective_from: Date.new(2024, 9, 1),
            active: true,
            notes: "賃金規則（2024年9月1日改訂）より"
          )

          if record.save
            if is_new
              created_count += 1
              puts "Created: #{grade_code} - ¥#{base_salary.to_fs(:delimited)}"
            else
              updated_count += 1
              puts "Updated: #{grade_code} - ¥#{base_salary.to_fs(:delimited)}"
            end
          else
            puts "Error: #{grade_code} - #{record.errors.full_messages.join(', ')}"
          end
        end
      end

      # 専門職の登録
      specialist_grades.each do |grade, evaluations|
        evaluations.each do |eval_code, base_salary|
          grade_code = "専門職-#{grade}-#{eval_code}"
          grade_name = "専門職（整備） #{grade_names[grade]} #{evaluation_names[eval_code]}"

          record = GradeSalaryTable.find_or_initialize_by(grade_code: grade_code)
          is_new = record.new_record?

          record.assign_attributes(
            grade_name: grade_name,
            base_salary: base_salary,
            city_allowance: 0,
            overtime_rate: 1.25,
            late_night_rate: 0.25,
            holiday_rate: 1.35,
            effective_from: Date.new(2024, 9, 1),
            active: true,
            notes: "賃金規則（2024年9月1日改訂）より"
          )

          if record.save
            if is_new
              created_count += 1
              puts "Created: #{grade_code} - ¥#{base_salary.to_fs(:delimited)}"
            else
              updated_count += 1
              puts "Updated: #{grade_code} - ¥#{base_salary.to_fs(:delimited)}"
            end
          else
            puts "Error: #{grade_code} - #{record.errors.full_messages.join(', ')}"
          end
        end
      end

      puts "\n=== Summary ==="
      puts "Created: #{created_count}"
      puts "Updated: #{updated_count}"
      puts "Total: #{GradeSalaryTable.count}"
    end
  end

  desc "Import employee salary settings from evaluation Excel (評価.xlsx)"
  task import_settings: :environment do
    require "roo"

    tenant = Tenant.first
    unless tenant
      puts "No tenant found."
      exit 1
    end

    file_path = "data/salary/評価.xlsx"
    unless File.exist?(file_path)
      puts "File not found: #{file_path}"
      exit 1
    end

    xlsx = Roo::Excelx.new(file_path)
    xlsx.default_sheet = xlsx.sheets.first

    # Helper method to normalize names
    def normalize_name(name)
      name.to_s
        .gsub(/[\s　]+/, " ")  # Normalize all whitespace to single space
        .gsub("髙", "高")      # 旧字体→新字体
        .gsub("邊", "辺")
        .gsub("邉", "辺")
        .gsub("﨑", "崎")
        .gsub("澤", "沢")
        .strip
    end

    ActsAsTenant.with_tenant(tenant) do
      created_count = 0
      updated_count = 0
      skipped_count = 0
      errors = []

      # Build name to attendance employee_code mapping
      attendance_map = {}
      AttendanceMonthly.select(:employee_code, :employee_name).distinct.each do |a|
        normalized_name = normalize_name(a.employee_name.to_s)
        attendance_map[normalized_name] = a.employee_code
        # Also try without spaces
        attendance_map[normalized_name.gsub(" ", "")] = a.employee_code
      end

      # Row 4 onwards contains employee data
      # Column mapping (0-indexed):
      # 0: 所属, 1: 氏名, 2: 職位, 3: 職責
      # 13: 2025年度等級, 14: 2025年度評価
      # 16: 基本給, 17: 職位加算, 18: 職責加算, 19: 大都市加算

      (4..xlsx.last_row).each do |row_num|
        row = xlsx.row(row_num)
        location = row[0].to_s.strip
        raw_name = row[1].to_s.strip
        name = normalize_name(raw_name)
        next if name.empty?

        grade = row[13].to_s.strip
          .gsub("級", "")  # "M級" -> "M"
          .gsub("Ｅ", "E").gsub("Ｈ", "H").gsub("Ｍ", "M").gsub("Ｇ", "G")  # 全角→半角
          .gsub(/.*?([EHMG]).*/, '\1')  # "G/専門職G" -> "G", "専門職Ｈ" -> "H"
        evaluation = row[14].to_s.strip
          .gsub("３", "3").gsub("２", "2")  # 全角数字→半角
          .gsub("Ａ", "A").gsub("Ｂ", "B").gsub("Ｓ", "S")  # 全角英字→半角
        next if grade.empty? || evaluation.empty?

        base_salary = row[16].to_i
        position_allowance = row[17].to_i  # 職位加算
        role_allowance = row[18].to_i      # 職責加算
        city_allowance = row[19].to_i      # 大都市加算

        # Find employee by name from attendance data
        employee_code = attendance_map[name] || attendance_map[name.gsub(" ", "")]

        # Try partial match if exact match fails
        unless employee_code
          name_parts = name.split(" ")
          attendance_map.each do |att_name, code|
            if name_parts.all? { |part| att_name.include?(part) }
              employee_code = code
              break
            end
          end
        end

        unless employee_code
          skipped_count += 1
          errors << "勤怠データに見つかりません: #{name} (#{location})"
          next
        end

        # Find or create employee
        employee = Employee.find_by(employee_code: employee_code)
        unless employee
          employee = Employee.create!(
            employee_code: employee_code,
            full_name: name,
            email: "#{employee_code}@example.com",
            current_status: "active"
          )
          puts "Created employee: #{employee_code} - #{name}"
        end

        # Determine job type based on grade
        job_type = if grade.include?("総務") || grade.include?("経理")
                     nil  # Skip non-driver/specialist for now
                   else
                     "運転職"
                   end

        unless job_type
          skipped_count += 1
          errors << "非運転職のためスキップ: #{name} (#{grade})"
          next
        end

        # Find grade salary table
        grade_code = "#{job_type}-#{grade}-#{evaluation}"
        grade_table = GradeSalaryTable.find_by(grade_code: grade_code)

        unless grade_table
          skipped_count += 1
          errors << "等級テーブルが見つかりません: #{grade_code} (#{name})"
          next
        end

        # Create or update salary setting
        setting = SalarySetting.find_or_initialize_by(
          employee_id: employee.id,
          effective_from: Date.new(2024, 9, 1)
        )
        is_new = setting.new_record?

        setting.assign_attributes(
          grade_salary_table_id: grade_table.id,
          salary_type: "monthly",
          position_allowance: position_allowance,
          qualification_allowance: role_allowance,
          housing_allowance: city_allowance,  # 大都市加算をhousing_allowanceに保存
          active: true
        )

        if setting.save
          if is_new
            created_count += 1
            puts "Created: #{employee.full_name} (#{employee_code}) -> #{grade_code}"
          else
            updated_count += 1
            puts "Updated: #{employee.full_name} (#{employee_code}) -> #{grade_code}"
          end
        else
          errors << "保存エラー: #{name} - #{setting.errors.full_messages.join(', ')}"
        end
      end

      puts "\n=== Summary ==="
      puts "Created: #{created_count}"
      puts "Updated: #{updated_count}"
      puts "Skipped: #{skipped_count}"
      puts "Total settings: #{SalarySetting.count}"

      if errors.any?
        puts "\n=== Errors/Warnings ==="
        errors.first(20).each { |e| puts "  - #{e}" }
        puts "  ... and #{errors.size - 20} more" if errors.size > 20
      end
    end
  end

  desc "Show all grade salary tables"
  task list: :environment do
    tenant = Tenant.first
    ActsAsTenant.with_tenant(tenant) do
      puts "\n=== 運転職 ==="
      GradeSalaryTable.where("grade_code LIKE ?", "運転職%").order(:grade_code).each do |g|
        puts "#{g.grade_code.ljust(15)} | #{g.grade_name.ljust(30)} | ¥#{g.base_salary.to_fs(:delimited).rjust(10)}"
      end

      puts "\n=== 専門職 ==="
      GradeSalaryTable.where("grade_code LIKE ?", "専門職%").order(:grade_code).each do |g|
        puts "#{g.grade_code.ljust(15)} | #{g.grade_name.ljust(30)} | ¥#{g.base_salary.to_fs(:delimited).rjust(10)}"
      end
    end
  end
end
