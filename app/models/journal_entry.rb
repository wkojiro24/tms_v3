class JournalEntry < ApplicationRecord
  include TenantScoped

  belongs_to :import_batch
  has_many :journal_lines, dependent: :destroy

  accepts_nested_attributes_for :journal_lines

  validates :entry_date, presence: true
end
