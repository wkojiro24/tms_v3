class ClassificationRule < ApplicationRecord
  include TenantScoped

  enum nature: {
    fixed: "fixed",
    variable: "variable",
    split: "split"
  }, _prefix: true

  scope :active, -> { where(active: true) }

  validates :name, presence: true
  validates :priority, numericality: { greater_than_or_equal_to: 0 }
  validates :nature, presence: true
end
