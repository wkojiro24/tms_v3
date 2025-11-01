class WorkflowRequestsController < ApplicationController
  helper WorkflowRequestsHelper
  before_action :authenticate_user!
  before_action :set_workflow_request, only: [:show]
  before_action :ensure_submission_permission, only: [:new, :create]

  def index
    @workflow_requests = current_user.admin_role? ? WorkflowRequest.recent.includes(:workflow_category) : WorkflowRequest.for_requester(current_user).recent.includes(:workflow_category)
    @workflow_requests = @workflow_requests.limit(50)
  end

  def new
    @workflow_request = WorkflowRequest.new(requester: current_user, requester_employee: current_user.employment)
    @categories = WorkflowCategory.active.includes(:stage_templates).order(:name)
    authorize! :create, @workflow_request
  end

  def create
    attributes = workflow_request_params.merge(
      requester: current_user,
      requester_employee: current_user.employment
    )
    @workflow_request = WorkflowRequest.new(attributes)
    authorize! :create, @workflow_request

    if @workflow_request.save
      @workflow_request.submit!
      redirect_to workflow_request_path(@workflow_request), notice: "申請を受け付けました。承認フローを開始します。"
    else
      @categories = WorkflowCategory.active.includes(:stage_templates).order(:name)
      flash.now[:alert] = "申請を作成できませんでした。入力内容をご確認ください。"
      render :new, status: :unprocessable_entity
    end
  end

  def show
    authorize! :read, @workflow_request
    @stages = @workflow_request.stages.includes(:responsible_user, :approvals)
    @notes = @workflow_request.notes.includes(:author).order(:created_at)
  end

  private

  def set_workflow_request
    @workflow_request = WorkflowRequest.find(params[:id])
  end

  def workflow_request_params
    metadata_keys = WorkflowRequest::METADATA_FIELDS.keys
    params.require(:workflow_request).permit(
      :workflow_category_id,
      :title,
      :summary,
      :amount,
      :currency,
      :vendor_name,
      :vehicle_identifier,
      :needed_on,
      :additional_information,
      metadata: metadata_keys,
      documents: []
    )
  end

  def ensure_submission_permission
    employment = current_user&.employment
    unless employment&.submit_enabled?
      redirect_to workflow_requests_path, alert: "申請権限がありません。管理者にお問い合わせください。"
    end
  end
end
