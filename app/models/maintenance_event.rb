class MaintenanceEvent < ApplicationRecord
  STANDARD_CATEGORY_KEYS = %w[shaken shuuri tenken tire].freeze
  STATUSES = %w[scheduled done canceled].freeze
  has_many_attached :photos

  belongs_to :vehicle, primary_key: :registration_number, foreign_key: :vehicle_number, optional: true

  validates :vehicle_number, presence: true
  validates :category, presence: true
  validates :start_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :end_after_start

  def standard_kind?
    STANDARD_CATEGORY_KEYS.include?(category.to_s)
  end

  def needs_attention?
    !standard_kind?
  end

  private

  def end_after_start
    return if end_at.blank? || start_at.blank?
    return if end_at > start_at

    errors.add(:end_at, "must be after start_at")
  end
end
