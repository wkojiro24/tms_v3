class User < ApplicationRecord
  include TenantScoped

  attr_accessor :tenant_name

  belongs_to :employment, class_name: "Employee"

  alias_method :employee, :employment
  alias_method :employee=, :employment=

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  enum role: {
    staff: "staff",
    admin: "admin"
  }, _suffix: true

  validates :role, presence: true
  validates :email, uniqueness: { scope: :tenant_id, case_sensitive: false }
  validates :employment, presence: true
  validates :employment_id, uniqueness: true
  validate :employment_belongs_to_tenant

  def display_name
    return employment.display_label if employment&.display_label.present?

    full_name = respond_to?(:full_name) ? self.full_name : nil
    full_name.present? ? full_name : email
  end

  def can_submit_workflow_requests?
    !!employment&.submit_enabled?
  end

  private

  def employment_belongs_to_tenant
    return if employment.blank?
    return if employment.tenant_id == tenant_id

    errors.add(:employment, "は同じテナントに属している必要があります。")
  end
end
