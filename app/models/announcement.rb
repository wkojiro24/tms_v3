class Announcement < ApplicationRecord
  include TenantScoped

  belongs_to :author, class_name: "User", optional: true

  validates :title, presence: true

  scope :published, -> { where("published_at <= ?", Time.current).where("expires_at IS NULL OR expires_at > ?", Time.current) }
  scope :pinned_first, -> { order(pinned: :desc, published_at: :desc) }
  scope :recent, -> { order(published_at: :desc) }
  scope :upcoming_events, -> { where("event_date >= ?", Date.current).order(:event_date) }
  scope :events_in_range, ->(start_date, end_date) { where(event_date: start_date..end_date) }

  # カテゴリ
  CATEGORIES = {
    "general" => "全般",
    "system" => "システム",
    "hr" => "人事",
    "safety" => "安全",
    "operation" => "運行",
    "event" => "イベント",
    "training" => "研修",
    "maintenance" => "整備"
  }.freeze

  def category_label
    CATEGORIES[category] || category
  end

  def published?
    published_at.present? && published_at <= Time.current && (expires_at.nil? || expires_at > Time.current)
  end

  def draft?
    published_at.nil? || published_at > Time.current
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def event?
    event_date.present?
  end

  def upcoming_event?
    event? && event_date >= Date.current
  end

  def event_period
    return nil unless event?

    if event_end_date.present? && event_end_date != event_date
      "#{event_date.strftime('%Y/%m/%d')} 〜 #{event_end_date.strftime('%Y/%m/%d')}"
    else
      event_date.strftime("%Y/%m/%d")
    end
  end
end
