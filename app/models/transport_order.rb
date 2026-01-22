class TransportOrder < ApplicationRecord
  include TenantScoped

  belongs_to :vehicle, optional: true
  belongs_to :employee, optional: true
  belongs_to :department, optional: true
  belongs_to :shipper, optional: true
  belongs_to :origin_location, class_name: "Destination", optional: true
  belongs_to :destination_location, class_name: "Destination", optional: true

  has_many :dispatch_assignments, dependent: :nullify

  enum :status, { draft: 0, confirmed: 1, billed: 2, paid: 3 }

  validates :order_date, presence: true
  validates :order_no, uniqueness: { scope: :tenant_id }, allow_blank: true

  before_save :calculate_billing_total

  scope :by_date_range, ->(start_date, end_date) {
    where(order_date: start_date..end_date)
  }

  scope :unbilled, -> { where(billing_date: nil) }
  scope :billed_in, ->(year_month) {
    start_date = Date.parse("#{year_month}01")
    end_date = start_date.end_of_month
    where(billing_date: start_date..end_date)
  }

  scope :for_date, ->(date) { where(order_date: date) }
  scope :unassigned, -> { left_joins(:dispatch_assignments).where(dispatch_assignments: { id: nil }) }
  scope :ordered, -> { order(:order_date, :loading_time, :order_no) }

  # 表示用メソッド
  def display_name
    parts = []
    parts << shipper&.name if shipper
    parts << destination_location&.name if destination_location
    parts << "(#{quantity}#{unit})" if quantity.present?
    parts.join(" → ").presence || order_no || "オーダー##{id}"
  end

  def short_name
    destination_location&.name || shipper&.name || order_no || "##{id}"
  end

  def loading_time_str
    loading_time&.strftime("%H:%M")
  end

  def departure_time_str
    departure_time&.strftime("%H:%M")
  end

  def arrival_time_str
    arrival_time&.strftime("%H:%M")
  end

  # 配車済みかどうか
  def assigned?
    dispatch_assignments.any?
  end

  private

  def calculate_billing_total
    self.billing_total = (billing_base_amount || 0) +
                         (billing_surcharge || 0) +
                         (billing_toll || 0) +
                         (billing_other || 0) +
                         (billing_tax || 0)
  end
end
