def ensure_user(email, role)
  User.find_or_create_by!(email: email) do |user|
    user.password = "password"
    user.password_confirmation = "password"
    user.role = role
  end
end

def ensure_employee(code, last_name:, first_name:, email: nil)
  Employee.find_or_create_by!(employee_code: code) do |emp|
    emp.last_name = last_name
    emp.first_name = first_name
    emp.email = email
    emp.current_status = "active"
    emp.hire_date = Date.new(2015, 4, 1)
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

  category.stage_templates.destroy_all

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

# 初期ユーザー
ensure_user("admin@example.com", :admin)
ensure_user("staff@example.com", :staff)
ensure_user("approver@example.com", :admin)
ensure_user("manager@example.com", :admin)
ensure_user("maintenance@example.com", :staff)
ensure_user("purchasing@example.com", :staff)
ensure_user("accounting@example.com", :staff)

# サンプル社員（申請者選択用）
ensure_employee("1001", last_name: "山田", first_name: "太郎", email: "yamada@example.com")
ensure_employee("1002", last_name: "佐藤", first_name: "花子", email: "sato@example.com")
ensure_employee("1003", last_name: "高橋", first_name: "誠")
ensure_employee("2001", last_name: "田中", first_name: "裕介")
ensure_employee("2002", last_name: "鈴木", first_name: "美咲")
ensure_employee("3001", last_name: "中村", first_name: "健一")

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

puts "Seeded default users, employees, and workflow categories" if Rails.env.development?
