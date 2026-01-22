class JournalLine < ApplicationRecord
  belongs_to :journal_entry

  enum :side, { debit: "debit", credit: "credit" }

  validates :side, presence: true
  validates :account_name, presence: true
  validates :amount, presence: true
end
