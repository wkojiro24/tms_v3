class MaintenanceEvent < ApplicationRecord
  belongs_to :vehicle, primary_key: :registration_number, foreign_key: :vehicle_number, optional: true

  validates :vehicle_number, presence: true
  validates :category, presence: true
  validates :start_at, presence: true
  validate :end_after_start

  private

  def end_after_start
    return if end_at.blank? || start_at.blank?
    return if end_at > start_at

    errors.add(:end_at, "must be after start_at")
  end
end
