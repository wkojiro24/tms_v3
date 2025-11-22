class MetricCategoryItem < ApplicationRecord
  belongs_to :metric_category

  serialize :source_labels, coder: JSON

  validates :display_label, presence: true
  validate :source_labels_presence

  scope :ordered, -> { order(:position, :id) }

  before_validation :ensure_display_label

  def source_label_list
    Array(source_labels).map(&:to_s).reject(&:blank?)
  end

  def source_label_text=(value)
    labels = value.to_s.split(/\r?\n|,/).map { |label| label.strip }.reject(&:blank?)
    self.source_labels = labels
  end

  def source_label_text
    source_label_list.join("\n")
  end

  private

  def source_labels_presence
    errors.add(:source_labels, "を1つ以上指定してください") if source_label_list.blank?
  end

  def ensure_display_label
    self.display_label = source_label_list.first if display_label.blank?
  end
end
