class Period < ApplicationRecord
  has_many :item_orders, dependent: :destroy
  has_many :items, through: :item_orders
  has_many :payroll_cells, dependent: :destroy
  has_many :payroll_column_orders, dependent: :destroy
  has_many :payroll_batches, dependent: :destroy

  validates :year, presence: true
  validates :month, presence: true, inclusion: { in: 1..12 }
  validates :month, uniqueness: { scope: :year }

  scope :ordered, -> { order(year: :desc, month: :desc) }

  def to_date
    Date.new(year, month, 1)
  end

  def label
    "#{year}-#{format('%02d', month)}"
  end
end
