class ImportBatch < ApplicationRecord
  include TenantScoped

  has_many :journal_entries, dependent: :destroy
  has_many :journal_lines, through: :journal_entries

  validates :source_file_name, presence: true
  validates :imported_at, presence: true
end
