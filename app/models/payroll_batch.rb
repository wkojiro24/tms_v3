class PayrollBatch < ApplicationRecord
  include TenantScoped

  belongs_to :period
  belongs_to :uploaded_by, class_name: "User"

  has_many :payroll_cells, dependent: :nullify

  enum status: {
    pending: "pending",
    processing: "processing",
    completed: "completed",
    failed: "failed"
  }, _prefix: true

  validates :status, presence: true
end
