class MaintenanceCategory < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
end
