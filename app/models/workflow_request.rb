class WorkflowRequest < ApplicationRecord
  include TenantScoped

  STATUSES = %w[draft pending approved rejected returned cancelled].freeze

  belongs_to :workflow_category
  belongs_to :requester, class_name: "User"
  belongs_to :requester_employee, class_name: "Employee", optional: true

  has_many :stages, -> { order(:position) }, class_name: "WorkflowStage", dependent: :destroy
  has_many :approvals, through: :stages
  has_many :notes, class_name: "WorkflowNote", dependent: :destroy

  has_many_attached :documents

  validates :title, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :currency, presence: true
  validates :requester_employee, presence: true

  after_create :build_default_stages
  after_initialize :set_defaults, if: :new_record?

  scope :recent, -> { order(submitted_at: :desc, created_at: :desc) }
  scope :for_requester, ->(user) { where(requester: user) }
  scope :pending_action_for, lambda { |user|
    joins(:stages)
      .where(workflow_stages: { status: "active" })
      .where(
        WorkflowStage.arel_table[:responsible_user_id].eq(user.id)
        .or(WorkflowStage.arel_table[:responsible_role].eq(user.role))
      )
      .distinct
  }

  def submit!
    return unless status == "draft"

    transaction do
      update!(status: "pending", submitted_at: Time.current)
      activate_next_stage!
    end
  end

  METADATA_FIELDS = {
    travel_destination: { label: "訪問先", type: :text },
    travel_purpose: { label: "目的", type: :textarea },
    travel_start_on: { label: "出発日", type: :date },
    travel_end_on: { label: "帰着日", type: :date },
    travel_members: { label: "同行者", type: :text },
    travel_transport: { label: "移動手段", type: :text },
    purchase_items: { label: "購入品目", type: :textarea },
    purchase_reason: { label: "購入理由", type: :textarea },
    purchase_supplier: { label: "仕入先候補", type: :text },
    purchase_expected_on: { label: "納品希望日", type: :date },
    repair_vehicle: { label: "対象車両", type: :text },
    repair_issue: { label: "故障内容", type: :textarea },
    repair_estimate_number: { label: "見積番号", type: :text },
    repair_cost_center: { label: "費用負担部署", type: :text },
    challenge_summary: { label: "取り組み内容", type: :textarea },
    challenge_benefit: { label: "期待効果", type: :textarea },
    challenge_team: { label: "関係メンバー", type: :text },
    asset_item: { label: "資産・備品名", type: :text },
    asset_current_location: { label: "現在の場所", type: :text },
    asset_new_location: { label: "移動/売却先", type: :text },
    asset_reason: { label: "理由", type: :textarea },
    incident_datetime: { label: "発生日時", type: :datetime },
    incident_location: { label: "発生場所", type: :text },
    incident_description: { label: "状況詳細", type: :textarea },
    incident_response: { label: "初動対応", type: :textarea },
    incident_cost_impact: { label: "想定損害/費用", type: :text }
  }.freeze

  store_accessor :metadata, *METADATA_FIELDS.keys

  def current_stage
    stages.find_by(status: "active") || stages.find_by(status: "pending")
  end

  def complete_stage(stage, action:, actor:, comment: nil)
    transaction do
      stage.complete!(action:, actor:, comment:)

      case action
      when "approved"
        if next_stage = next_pending_stage
          next_stage.activate!
        else
          finalize!(result: "approved")
        end
      when "returned"
        update!(status: "returned")
      when "rejected"
        finalize!(result: "rejected")
      when "held"
        update!(status: "pending") unless status == "pending"
      end
    end
  end

  def next_pending_stage
    stages.where(status: "pending").order(:position).first
  end

  def human_status
    status.humanize
  end

  def notify_final_approval!(actor:)
    roles = workflow_category.notification_roles
    return if roles.blank?

    actor_name = actor&.display_name || "system"
    Rails.logger.info("[Workflow] #{id} approved by #{actor_name}. Notifying roles: #{roles.join(', ')}")
    # TODO: integrate with mailer/notification system
  end

  def metadata_entries
    METADATA_FIELDS.each_with_object([]) do |(key, meta), list|
      value = send(key)
      next if value.blank?

      formatted = case meta[:type]
                  when :date
                    parse_date(value) || value
                  when :datetime
                    parse_datetime(value) || value
                  else
                    value
                  end

      list << { key:, label: meta[:label], value: formatted }
    end
  end

  private

  def set_defaults
    self.currency ||= "JPY"
  end

  def parse_date(value)
    Date.parse(value.to_s).strftime("%Y-%m-%d")
  rescue ArgumentError, TypeError
    nil
  end

  def parse_datetime(value)
    zone = Time.zone || Time
    zone.parse(value.to_s).strftime("%Y-%m-%d %H:%M")
  rescue ArgumentError, TypeError
    nil
  end

  def build_default_stages
    return if stages.exists?

    workflow_category.default_stage_attributes.each do |attrs|
      stages.create!(attrs.merge(status: "pending"))
    end
  end

  def activate_next_stage!
    stage = next_pending_stage
    if stage
      stage.activate!
    else
      finalize!(result: "approved") if status == "pending"
    end
  end

  def finalize!(result:)
    update!(status: result, finalized_at: Time.current)
    notify_final_approval!(actor: approvals.order(:acted_at).last&.actor) if result == "approved"
  end
end
