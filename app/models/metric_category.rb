class MetricCategory < ApplicationRecord
  has_many :items, class_name: "MetricCategoryItem", dependent: :destroy

  validates :name, presence: true, uniqueness: true
  validates :display_label, presence: true

  scope :ordered, -> { order(:position, :id) }

  before_validation :ensure_display_label

  private

  def ensure_display_label
    self.display_label = name if display_label.blank?
  end
end
