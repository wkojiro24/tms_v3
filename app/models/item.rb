class Item < ApplicationRecord
  has_many :item_orders, dependent: :destroy
  has_many :periods, through: :item_orders
  has_many :payroll_cells, dependent: :destroy

  validates :name, presence: true

  scope :alphabetical, -> { order(:name) }

  def monetary_section?
    above_basic?
  end
end
