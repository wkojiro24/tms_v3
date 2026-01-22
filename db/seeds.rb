tenant = Tenant.find_or_create_by!(slug: "default") do |record|
  record.name = "Default Tenant"
  record.time_zone = "Asia/Tokyo"
end

ActsAsTenant.with_tenant(tenant) do
  def ensure_employee(code, last_name:, first_name:, email: nil, submit_enabled: false,
                      department_code: nil, job_category_code: nil, job_position_code: nil,
                      grade_level_code: nil)
    Employee.find_or_initialize_by(employee_code: code).tap do |emp|
      emp.last_name = last_name
      emp.first_name = first_name
      emp.email = email if email.present?
      emp.full_name = [last_name, first_name].compact.join(" ")
      emp.current_status ||= "active"
      emp.hire_date ||= Date.new(2015, 4, 1)
      emp.submit_enabled = submit_enabled
      emp.department = Department.find_by(code: department_code) if department_code.present?
      emp.job_category = JobCategory.find_by(code: job_category_code) if job_category_code.present?
      emp.job_position = JobPosition.find_by(code: job_position_code) if job_position_code.present?
      emp.grade_level = GradeLevel.find_by(code: grade_level_code) if grade_level_code.present?
      emp.save!
    end
  end

  def ensure_user(email:, role:, employee_code:)
    employment = Employee.find_by!(employee_code: employee_code)
    employment.update!(email: email) if employment.email.blank?
    employment.update!(submit_enabled: true)

    User.find_or_initialize_by(email: email).tap do |user|
      user.password = "password"
      user.password_confirmation = "password"
      user.role = role
      user.employment = employment
      user.save!
    end
  end

  def configure_category(code:, name:, description:, stages:, notifications: [])
    puts "[seed-category] code=#{code.inspect} name=#{name.inspect} description=#{description.inspect}"

    WorkflowCategory.where(code: code).find_each do |existing|
      existing.stage_templates.destroy_all
      existing.notifications.destroy_all
    end
    WorkflowCategory.where(code: code).delete_all

    category = WorkflowCategory.create!(code: code, name: name, description: description, active: true)

    Array(stages).compact.each_with_index do |stage, index|
      data = stage.respond_to?(:to_h) ? stage.to_h : { name: stage }
      data = data.symbolize_keys

      stage_name = data[:name].to_s.strip
      stage_name = "ステップ#{index + 1}" if stage_name.blank?

      responsible_user = data[:user]
      responsible_user ||= data[:user_email]&.then { |email| User.find_by(email:) }

      category.stage_templates.create!(
        position: index + 1,
        name: stage_name,
        responsible_role: data[:role],
        responsible_user: responsible_user,
        instructions: data[:instructions]
      )
    end

    category.notifications.destroy_all
    notifications.each do |notif|
      data = notif.respond_to?(:symbolize_keys) ? notif.symbolize_keys : notif
      category.notifications.create!(role: data[:role], description: data[:description])
    end
  end

  # マスターデータ
  departments = [
    { code: "HQ", name: "本社", description: "管理部門" },
    { code: "OPS", name: "運行部", description: "運行管理とドライバー" }
  ]
  departments.each do |attrs|
    Department.find_or_create_by!(code: attrs[:code]) do |record|
      record.name = attrs[:name]
      record.description = attrs[:description]
    end
  end

  job_categories = [
    { code: "driver", name: "ドライバー" },
    { code: "office", name: "事務" },
    { code: "specialist", name: "専門職" }
  ]
  job_categories.each do |attrs|
    JobCategory.find_or_create_by!(code: attrs[:code]) do |record|
      record.name = attrs[:name]
      record.description = attrs[:description]
    end
  end

  job_positions = [
    { code: "manager", name: "所長", grade: 3 },
    { code: "driver", name: "ドライバー", grade: 1 },
    { code: "office_lead", name: "主任", grade: 2 }
  ]
  job_positions.each do |attrs|
    JobPosition.find_or_create_by!(code: attrs[:code]) do |record|
      record.name = attrs[:name]
      record.grade = attrs[:grade]
      record.description = attrs[:description]
    end
  end

  grade_levels = [
    { code: "driver_band", name: "ドライバー等級" },
    { code: "office_band", name: "事務等級" },
    { code: "special_band", name: "専門職等級" }
  ]
  grade_levels.each do |attrs|
    GradeLevel.find_or_create_by!(code: attrs[:code]) do |record|
      record.name = attrs[:name]
      record.description = attrs[:description]
    end
  end

  evaluation_grades = [
    { code: "S", name: "S", score: 5 },
    { code: "3A", name: "3A", score: 4 },
    { code: "2A", name: "2A", score: 3 },
    { code: "A", name: "A", score: 2 },
    { code: "B", name: "B", score: 1 }
  ]
  evaluation_grades.each do |attrs|
    EvaluationGrade.find_or_create_by!(code: attrs[:code]) do |record|
      record.name = attrs[:name]
      record.score = attrs[:score]
      record.band = attrs[:band]
    end
  end

  evaluation_cycles = [
    { code: "2024H1", name: "2024年 上期", start_on: Date.new(2024, 4, 1), end_on: Date.new(2024, 9, 30) },
    { code: "2024H2", name: "2024年 下期", start_on: Date.new(2024, 10, 1), end_on: Date.new(2025, 3, 31) }
  ]
  evaluation_cycles.each do |attrs|
    EvaluationCycle.find_or_create_by!(code: attrs[:code]) do |record|
      record.name = attrs[:name]
      record.start_on = attrs[:start_on]
      record.end_on = attrs[:end_on]
    end
  end

  # サンプル従業員（Employment）
  ensure_employee("1001", last_name: "山田", first_name: "太郎", email: "yamada@example.com", submit_enabled: true,
                  department_code: "OPS", job_category_code: "driver", job_position_code: "driver",
                  grade_level_code: "driver_band")
  ensure_employee("1002", last_name: "佐藤", first_name: "花子", email: "sato@example.com", submit_enabled: true,
                  department_code: "OPS", job_category_code: "driver", job_position_code: "driver",
                  grade_level_code: "driver_band")
  ensure_employee("1003", last_name: "高橋", first_name: "誠",
                  department_code: "OPS", job_category_code: "specialist", grade_level_code: "special_band")
  ensure_employee("2001", last_name: "田中", first_name: "裕介",
                  department_code: "HQ", job_category_code: "office", job_position_code: "office_lead",
                  grade_level_code: "office_band")
  ensure_employee("2002", last_name: "鈴木", first_name: "美咲",
                  department_code: "HQ", job_category_code: "office", grade_level_code: "office_band")
  ensure_employee("3001", last_name: "中村", first_name: "健一",
                  department_code: "OPS", job_category_code: "driver", grade_level_code: "driver_band")

  # ログイン権限を持つ従業員（User）
  # 管理者用アカウント
  ensure_employee("A100", last_name: "Default", first_name: "Admin", email: "admin@default.com", submit_enabled: true,
                  department_code: "HQ", job_category_code: "office", job_position_code: "manager")
  ensure_user(email: "admin@default.com", role: :admin, employee_code: "A100")

  # スタッフ例: wkojiro22 さん
  ensure_employee("S100", last_name: "Wkojirou", first_name: "Staff", email: "wkojiro22@gmail.com", submit_enabled: true,
                  department_code: "OPS", job_category_code: "driver", grade_level_code: "driver_band")
  ensure_user(email: "wkojiro22@gmail.com", role: :staff, employee_code: "S100")

  # ワークフローカテゴリ & 承認ルート
  configure_category(
    code: "business_trip",
    name: "出張申請",
    description: "出張に伴う旅費・宿泊費等の承認",
    stages: [
      { name: "所属長承認", role: "staff", instructions: "出張の必要性を確認" },
      { name: "管理部確認", role: "admin", instructions: "費用の妥当性・予算確認" }
    ],
    notifications: [{ role: "accounting", description: "旅費精算のため経理へ共有" }]
  )

  configure_category(
    code: "purchase_request",
    name: "購買申請",
    description: "備品・消耗品の購入申請",
    stages: [
      { name: "所属長承認", role: "staff", instructions: "購入理由と予算枠を確認" },
      { name: "購買管理", role: "admin", instructions: "見積比較と最終判断" }
    ],
    notifications: [{ role: "accounting", description: "支払処理・仕訳の準備" }]
  )

  configure_category(
    code: "vehicle_repair",
    name: "高額修理申請",
    description: "車両の大型修理・改造に関する承認",
    stages: [
      { name: "整備担当確認", role: "staff", instructions: "故障状況と使用可否を確認" },
      { name: "管理部承認", role: "admin", instructions: "費用・稼働影響を確認" }
    ],
    notifications: [{ role: "accounting", description: "修理費用の計上手続き" }]
  )

  configure_category(
    code: "challenge_program",
    name: "チャレンジ制度適用",
    description: "改善・新規施策の実施申請",
    stages: [
      { name: "所属長承認", role: "staff", instructions: "施策内容と人員計画を確認" },
      { name: "経営会議承認", role: "admin", instructions: "投資対効果・リスクの確認" }
    ]
  )

  configure_category(
    code: "asset_transfer",
    name: "資産移動・売却",
    description: "車両や備品の移動／処分／売却に関する承認",
    stages: [
      { name: "現場責任者", role: "staff", instructions: "現場利用状況を確認" },
      { name: "管理部承認", role: "admin", instructions: "帳簿価額・償却状況を確認" }
    ],
    notifications: [{ role: "accounting", description: "資産台帳・在庫リストの更新" }]
  )

  configure_category(
    code: "incident_report",
    name: "事故報告",
    description: "事故・インシデント発生時の報告と対応共有",
    stages: [
      { name: "所属長確認", role: "staff", instructions: "初動対応の完了確認" },
      { name: "安全統括責任者", role: "admin", instructions: "原因分析と再発防止策確認" }
    ],
    notifications: [{ role: "accounting", description: "損害保険・費用計上の確認" }]
  )

  configure_category(
    code: "leave_request",
    name: "休暇申請",
    description: "有給休暇・特別休暇等の申請",
    stages: [
      { name: "所属長承認", role: "staff", instructions: "業務への影響と代替要員を確認" }
    ],
    notifications: []
  )

  metric_categories = [
    {
      name: "revenue",
      label: "売上",
      position: 0,
      items: [
        { label: "輸送収入", sources: ["輸送収入"] }
      ]
    },
    {
      name: "fixed_cost",
      label: "固定費",
      position: 1,
      items: [
        { label: "減価償却", sources: ["減価償却"] },
        { label: "自動車税", sources: ["自動車税"] },
        { label: "自動車重量税・取得税", sources: ["自動車重量税", "自動車取得税"] },
        { label: "自賠責保険", sources: ["自賠責保険"] },
        { label: "任意保険", sources: ["任意保険"] },
        { label: "車検費用", sources: ["車検"] },
        { label: "駐車場・地代", sources: ["駐車場代", "地代", "地代家賃"] }
      ]
    },
    {
      name: "variable_cost",
      label: "変動費",
      position: 2,
      items: [
        { label: "高速代", sources: ["高速代", "高速代計"] },
        { label: "軽油費", sources: ["軽油費"] },
        { label: "オイル", sources: ["その他燃料費", "油脂費"] },
        { label: "タイヤ・チューブ", sources: ["タイヤ・チューブ費"] },
        { label: "その他修繕費", sources: ["一般修理費", "部品費"] }
      ]
    },
    {
      name: "driver_cost",
      label: "ドライバー人件費",
      position: 3,
      items: [
        { label: "人件費", sources: ["人件費", "ドライバー人件費"] }
      ]
    },
    {
      name: "depot_admin",
      label: "営業所管理費",
      position: 4,
      items: [
        { label: "営業所管理費", sources: ["営業所管理費"] }
      ]
    },
    {
      name: "depot_personnel",
      label: "営業所人件費",
      position: 5,
      items: [
        { label: "営業所人件費", sources: ["営業所人件費"] }
      ]
    },
    {
      name: "hq_personnel",
      label: "本社人件費",
      position: 6,
      items: [
        { label: "本社人件費", sources: ["本社人件費"] }
      ]
    },
    {
      name: "hq_admin",
      label: "本社管理費",
      position: 7,
      items: [
        { label: "本社管理費", sources: ["本社管理費"] }
      ]
    },
    {
      name: "profit",
      label: "損益",
      position: 8,
      items: [
        { label: "損益", sources: ["損益"] }
      ]
    }
  ]

  metric_categories.each do |category_attrs|
    category = MetricCategory.find_or_initialize_by(name: category_attrs[:name])
    category.display_label = category_attrs[:label]
    category.position = category_attrs[:position]
    category.save!

    category.items.delete_all
    category_attrs[:items].each_with_index do |item_attrs, index|
      category.items.create!(
        display_label: item_attrs[:label],
        source_labels: item_attrs[:sources],
        position: index + 1
      )
    end
  end

  def ensure_pl_node(code:, name:, parent_code: nil, display_order: 0, node_type: "normal", expression: nil)
    parent = parent_code.present? ? PlTreeNode.find_by!(code: parent_code) : nil
    PlTreeNode.find_or_initialize_by(code: code).tap do |node|
      node.parent = parent
      node.name = name
      node.display_order = display_order
      node.depth = parent ? parent.depth + 1 : 0
      node.node_type = node_type
      node.expression = expression
      node.save!
    end
  end

  pl_nodes = [
    { code: "sales", name: "売上", display_order: 10 },
    { code: "sales_revenue", name: "売上高", parent_code: "sales", display_order: 10 },
    { code: "cost_of_sales", name: "原価", display_order: 20 },
    { code: "fuel_cost", name: "燃料費", parent_code: "cost_of_sales", display_order: 10 },
    { code: "repair_cost", name: "修繕費", parent_code: "cost_of_sales", display_order: 20 },
    { code: "tire_cost", name: "タイヤ費", parent_code: "cost_of_sales", display_order: 30 },
    { code: "toll_cost", name: "通行料（ETC等）", parent_code: "cost_of_sales", display_order: 40 },
    { code: "supplies_cost", name: "消耗品費", parent_code: "cost_of_sales", display_order: 50 },
    { code: "outsourcing_cost", name: "外注費", parent_code: "cost_of_sales", display_order: 60 },
    { code: "labor_cost", name: "労務費（可変）", parent_code: "cost_of_sales", display_order: 70 },
    { code: "cost_unclassified", name: "未分類（原価）", parent_code: "cost_of_sales", display_order: 999 },
    { code: "branch_admin", name: "営業所管理費", display_order: 30 },
    { code: "operation_admin", name: "運行管理費", parent_code: "branch_admin", display_order: 10 },
    { code: "office_cost", name: "事務費", parent_code: "branch_admin", display_order: 20 },
    { code: "utilities_cost", name: "水道光熱費", parent_code: "branch_admin", display_order: 30 },
    { code: "communication_cost", name: "通信費", parent_code: "branch_admin", display_order: 40 },
    { code: "branch_unclassified", name: "未分類（営業所）", parent_code: "branch_admin", display_order: 999 },
    { code: "hq_cost", name: "本社費", display_order: 40 },
    { code: "executive_pay", name: "役員報酬", parent_code: "hq_cost", display_order: 10 },
    { code: "hq_rent", name: "本社家賃", parent_code: "hq_cost", display_order: 20 },
    { code: "core_system", name: "基幹システム/デジタコ基本", parent_code: "hq_cost", display_order: 30 },
    { code: "insurance_cost", name: "保険料（包括）", parent_code: "hq_cost", display_order: 40 },
    { code: "tax_cost", name: "税金（本社計上分）", parent_code: "hq_cost", display_order: 50 },
    { code: "parking_cost", name: "駐車場代", parent_code: "hq_cost", display_order: 60 },
    { code: "hq_unclassified", name: "未分類（本社）", parent_code: "hq_cost", display_order: 999 },
    { code: "operating_income", name: "営業利益", display_order: 90, node_type: "calculated", expression: "sales - cost_of_sales - branch_admin - hq_cost" }
  ]
  pl_nodes.each { |attrs| ensure_pl_node(**attrs) }

  mapping_definitions = [
    { pl_code: "sales_revenue", priority: 10, account_name: "売上" },
    { pl_code: "fuel_cost", priority: 10, account_name: "燃料費" },
    { pl_code: "repair_cost", priority: 10, account_name: "修繕費" },
    { pl_code: "tire_cost", priority: 10, account_name: "タイヤ" },
    { pl_code: "toll_cost", priority: 10, account_name: "通行料" },
    { pl_code: "supplies_cost", priority: 10, account_name: "消耗品" },
    { pl_code: "outsourcing_cost", priority: 20, account_name: "外注費" },
    { pl_code: "labor_cost", priority: 30, account_name: "労務費" },
    { pl_code: "operation_admin", priority: 10, account_name: "運行管理費" },
    { pl_code: "office_cost", priority: 10, account_name: "事務費" },
    { pl_code: "utilities_cost", priority: 10, account_name: "水道光熱費" },
    { pl_code: "communication_cost", priority: 10, account_name: "通信費" },
    { pl_code: "executive_pay", priority: 10, account_name: "役員報酬" },
    { pl_code: "hq_rent", priority: 10, account_name: "家賃" },
    { pl_code: "core_system", priority: 10, account_name: "基幹システム" },
    { pl_code: "insurance_cost", priority: 10, account_name: "保険料" },
    { pl_code: "tax_cost", priority: 10, account_name: "税金" },
    { pl_code: "parking_cost", priority: 10, account_name: "駐車場" }
  ]
  mapping_definitions.each do |definition|
    node = PlTreeNode.find_by!(code: definition[:pl_code])
    attributes = definition.except(:pl_code)
    mapping = PlMapping.find_or_initialize_by(
      pl_tree_node: node,
      mapping_scope: attributes[:mapping_scope] || "company",
      account_name: attributes[:account_name]
    )
    mapping.priority = attributes[:priority]
    mapping.vendor_name = attributes[:vendor_name] if attributes[:vendor_name]
    mapping.memo_keyword = attributes[:memo_keyword] if attributes[:memo_keyword]
    mapping.active = true
    mapping.save!
  end

  classification_definitions = [
    { name: "固定費:保険料", priority: 10, nature: "fixed", conditions: { account_name: ["保険"] } },
    { name: "固定費:家賃・駐車場", priority: 20, nature: "fixed", conditions: { account_name: %w[家賃 駐車場 リース] } },
    { name: "固定費:システム", priority: 30, nature: "fixed", conditions: { memo_keyword: ["デジタコ", "基幹"] } },
    { name: "変動費:燃料", priority: 10, nature: "variable", conditions: { account_name: ["燃料費"] } },
    { name: "変動費:ETC", priority: 20, nature: "variable", conditions: { account_name: ["通行料"] } },
    { name: "変動費:整備", priority: 30, nature: "variable", conditions: { account_name: ["修繕費", "タイヤ"] } },
    { name: "変動費:消耗品", priority: 40, nature: "variable", conditions: { account_name: ["消耗品"] } }
  ]
  classification_definitions.each do |definition|
    rule = ClassificationRule.find_or_initialize_by(name: definition[:name])
    rule.priority = definition[:priority]
    rule.nature = definition[:nature]
    rule.conditions = definition[:conditions]
    rule.active = true
    rule.save!
  end

  vehicles_csv = Rails.root.join("data/journals/車両台帳一覧表.csv")
  if File.exist?(vehicles_csv)
    puts "[seed] Importing vehicles from #{vehicles_csv}"
    VehicleImporter.new(vehicles_csv).import!
  else
    puts "[seed] Vehicle CSV not found at #{vehicles_csv}"
  end

  # 荷主マスター
  shippers_data = [
    { code: "SHP001", name: "東京化学工業", address: "東京都江東区豊洲1-1-1", phone: "03-1234-5678" },
    { code: "SHP002", name: "関東石油化学", address: "神奈川県川崎市川崎区千鳥町1-1", phone: "044-123-4567" },
    { code: "SHP003", name: "日本製紙工業", address: "静岡県富士市大渕1-1-1", phone: "0545-12-3456" },
    { code: "SHP004", name: "横浜ケミカル", address: "神奈川県横浜市鶴見区大黒町1-1", phone: "045-111-2222" },
    { code: "SHP005", name: "千葉コンビナート", address: "千葉県市原市五井海岸1-1", phone: "0436-22-3333" },
    { code: "SHP006", name: "埼玉物流センター", address: "埼玉県戸田市美女木1-1", phone: "048-444-5555" }
  ]
  shippers_data.each do |attrs|
    Shipper.find_or_create_by!(code: attrs[:code]) do |s|
      s.name = attrs[:name]
      s.address = attrs[:address]
      s.phone = attrs[:phone]
    end
  end
  puts "[seed] Created #{shippers_data.size} shippers"

  # 積み場・卸場（Destination）マスター
  destinations_data = [
    # 積み場（ターミナル・製造拠点）
    { code: "L001", name: "川崎ターミナル", address: "神奈川県川崎市川崎区千鳥町5-1", latitude: 35.5180, longitude: 139.7560 },
    { code: "L002", name: "横浜ベイサイド基地", address: "神奈川県横浜市鶴見区大黒ふ頭1", latitude: 35.4741, longitude: 139.6680 },
    { code: "L003", name: "市原コンビナート", address: "千葉県市原市五井海岸1番地", latitude: 35.4891, longitude: 140.0895 },
    { code: "L004", name: "東京港積込場", address: "東京都江東区青海2-5-10", latitude: 35.6189, longitude: 139.7780 },
    { code: "L005", name: "鹿島石油基地", address: "茨城県神栖市東深芝20", latitude: 35.8901, longitude: 140.6720 },

    # 卸場（工場・倉庫）
    { code: "D001", name: "足利工場", address: "栃木県足利市大月町1-1", latitude: 36.3350, longitude: 139.4500 },
    { code: "D002", name: "太田物流センター", address: "群馬県太田市新田早川町1-1", latitude: 36.3001, longitude: 139.3800 },
    { code: "D003", name: "所沢配送センター", address: "埼玉県所沢市東住吉1-1", latitude: 35.7990, longitude: 139.4690 },
    { code: "D004", name: "八王子倉庫", address: "東京都八王子市石川町1-1", latitude: 35.6589, longitude: 139.3360 },
    { code: "D005", name: "相模原工場", address: "神奈川県相模原市中央区田名1-1", latitude: 35.5580, longitude: 139.3750 },
    { code: "D006", name: "厚木配送センター", address: "神奈川県厚木市酒井1-1", latitude: 35.4420, longitude: 139.3620 },
    { code: "D007", name: "藤沢工場", address: "神奈川県藤沢市辻堂神台1-1", latitude: 35.3490, longitude: 139.4540 },
    { code: "D008", name: "茅ヶ崎プラント", address: "神奈川県茅ヶ崎市柳島1-1", latitude: 35.3240, longitude: 139.4020 },
    { code: "D009", name: "小田原倉庫", address: "神奈川県小田原市酒匂1-1", latitude: 35.2680, longitude: 139.1580 },
    { code: "D010", name: "沼津工場", address: "静岡県沼津市原1-1-1", latitude: 35.0960, longitude: 138.8560 },
    { code: "D011", name: "富士化学工場", address: "静岡県富士市大渕1-1-1", latitude: 35.1620, longitude: 138.6770 },
    { code: "D012", name: "静岡配送センター", address: "静岡県静岡市駿河区用宗1-1", latitude: 34.9420, longitude: 138.3550 },
    { code: "D013", name: "浜松プラント", address: "静岡県浜松市南区新橋町1-1", latitude: 34.6910, longitude: 137.7250 },
    { code: "D014", name: "豊橋工場", address: "愛知県豊橋市神野新田町1-1", latitude: 34.7380, longitude: 137.3880 },
    { code: "D015", name: "名古屋港倉庫", address: "愛知県名古屋市港区金城ふ頭1-1", latitude: 35.0450, longitude: 136.8420 },

    # 追加の積み場
    { code: "L006", name: "清水港ターミナル", address: "静岡県静岡市清水区日の出町1-1", latitude: 35.0130, longitude: 138.4980 },
    { code: "L007", name: "四日市石油基地", address: "三重県四日市市霞1-1", latitude: 34.9670, longitude: 136.6260 }
  ]
  destinations_data.each do |attrs|
    shipper = Shipper.first # デフォルトで最初の荷主に紐付け
    Destination.find_or_create_by!(code: attrs[:code]) do |d|
      d.name = attrs[:name]
      d.address = attrs[:address]
      d.latitude = attrs[:latitude]
      d.longitude = attrs[:longitude]
      d.shipper = shipper
    end
  end
  puts "[seed] Created #{destinations_data.size} destinations (loading/unloading points)"

  VehicleAlias.find_or_create_by!(pattern: "川崎100え1825") do |alias_record|
    alias_record.pattern_type = "exact"
    alias_record.vehicle_id = "KAW-1825"
  end

  puts "Seeded default tenant, users, employees, and workflow categories" if Rails.env.development?
end
