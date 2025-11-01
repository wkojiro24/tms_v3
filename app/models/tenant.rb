class Tenant < ApplicationRecord
  has_many :users, dependent: :destroy
  has_many :employees, dependent: :destroy
  has_many :workflow_categories, dependent: :destroy
  has_many :workflow_requests, dependent: :destroy
  has_many :departments, dependent: :destroy
  has_many :job_categories, dependent: :destroy
  has_many :job_positions, dependent: :destroy
  has_many :grade_levels, dependent: :destroy
  has_many :evaluation_grades, dependent: :destroy
  has_many :evaluation_cycles, dependent: :destroy

  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :ensure_slug
  after_initialize :set_defaults, if: :new_record?

  scope :active, -> { where(deleted_at: nil) }

  def to_param
    slug
  end

  private

  def ensure_slug
    return if slug.present?

    self.slug = name.to_s.parameterize.presence || "tenant-#{SecureRandom.hex(4)}"
  end

  def set_defaults
    self.time_zone ||= "Asia/Tokyo"
  end
end
