class Bookmark < ApplicationRecord
  include TenantScoped

  belongs_to :creator, class_name: "User", optional: true

  validates :title, presence: true
  validates :url, presence: true, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]), message: "は有効なURLを入力してください" }

  scope :shared, -> { where(shared: true) }
  scope :personal, -> { where(shared: false) }
  scope :for_user, ->(user) { where(shared: true).or(where(shared: false, creator: user)) }
  scope :personal_for, ->(user) { where(shared: false, creator: user) }
  scope :ordered, -> { order(:category, :position, :title) }
  scope :by_category, ->(cat) { where(category: cat) }

  # カテゴリ
  CATEGORIES = {
    "general" => "全般",
    "system" => "業務システム",
    "reference" => "参考資料",
    "government" => "官公庁",
    "partner" => "取引先",
    "internal" => "社内ツール"
  }.freeze

  # アイコン候補
  ICONS = {
    "link" => "bi-link-45deg",
    "globe" => "bi-globe",
    "file" => "bi-file-earmark",
    "folder" => "bi-folder",
    "building" => "bi-building",
    "truck" => "bi-truck",
    "person" => "bi-person",
    "gear" => "bi-gear",
    "calculator" => "bi-calculator",
    "calendar" => "bi-calendar",
    "graph" => "bi-graph-up",
    "box" => "bi-box"
  }.freeze

  def category_label
    CATEGORIES[category] || category
  end

  def icon_class
    ICONS[icon] || "bi-link-45deg"
  end

  def domain
    URI.parse(url).host rescue nil
  end
end
