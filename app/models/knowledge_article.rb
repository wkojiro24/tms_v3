class KnowledgeArticle < ApplicationRecord
  include TenantScoped

  belongs_to :author, class_name: "User", optional: true

  # Action Text for WYSIWYG content
  has_rich_text :content

  # File attachments
  has_many_attached :attachments

  validates :title, presence: true
  validates :slug, uniqueness: { scope: :tenant_id }, allow_blank: true

  before_validation :generate_slug, if: -> { slug.blank? && title.present? }

  scope :published, -> { where(published: true) }
  scope :draft, -> { where(published: false) }
  scope :ordered, -> { order(position: :asc, updated_at: :desc) }
  scope :by_category, ->(cat) { where(category: cat) }
  scope :recent, -> { order(published_at: :desc) }

  # カテゴリ
  CATEGORIES = {
    "manual" => "マニュアル",
    "procedure" => "業務手順",
    "faq" => "よくある質問",
    "rule" => "社内規定",
    "safety" => "安全管理",
    "system" => "システム操作",
    "other" => "その他"
  }.freeze

  def category_label
    CATEGORIES[category] || category
  end

  def to_param
    slug.presence || id.to_s
  end

  def increment_view_count!
    increment!(:view_count)
  end

  def tag_list
    tags.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def tag_list=(list)
    self.tags = Array(list).join(",")
  end

  def publish!
    update(published: true, published_at: Time.current)
  end

  def unpublish!
    update(published: false)
  end

  private

  def generate_slug
    base_slug = title.to_s.parameterize
    base_slug = "article-#{SecureRandom.hex(4)}" if base_slug.blank?

    slug_candidate = base_slug
    counter = 1
    while KnowledgeArticle.exists?(tenant_id: tenant_id, slug: slug_candidate)
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end
    self.slug = slug_candidate
  end
end
