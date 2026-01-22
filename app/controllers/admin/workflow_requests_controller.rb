module Admin
  class WorkflowRequestsController < BaseController
    helper WorkflowRequestsHelper
    before_action :set_workflow_request, only: [:show, :decide, :comment]

    def index
      @pending_stages = WorkflowStage.active.includes(:workflow_request, :responsible_user)
                                     .select { |stage| stage.actionable_by?(current_user) || current_user.admin_role? }
      @recent_requests = WorkflowRequest.recent.includes(:workflow_category, :requester).limit(50)
    end

    def show
      @stages = @workflow_request.stages.includes(:responsible_user, :approvals)
      @current_stage = @stages.find { |stage| stage.status == "active" }
      @can_act = @current_stage&.actionable_by?(current_user) || current_user.admin_role?
      @notes = @workflow_request.notes.includes(:author).order(:created_at)
    end

    def decide
      action = params[:decision]
      unless %w[approved rejected returned held].include?(action)
        redirect_to admin_workflow_request_path(@workflow_request), alert: "不正な操作です。" and return
      end

      process_action!(action)
    end

    def comment
      note = @workflow_request.notes.build(author: current_user, body: params[:comment])
      if note.save
        redirect_to admin_workflow_request_path(@workflow_request), notice: "コメントを追加しました。"
      else
        redirect_to admin_workflow_request_path(@workflow_request), alert: "コメントを追加できませんでした。"
      end
    end

    private

    def set_workflow_request
      @workflow_request = WorkflowRequest.find(params[:id])
      authorize! :read, @workflow_request
    end

    def process_action!(action)
      stage = @workflow_request.current_stage
      unless stage
        redirect_to admin_workflow_request_path(@workflow_request), alert: "処理できるステージが見つかりません。" and return
      end
      unless stage&.actionable_by?(current_user) || current_user.admin_role?
        redirect_to admin_workflow_request_path(@workflow_request), alert: "この申請を操作する権限がありません。" and return
      end

      @workflow_request.complete_stage(stage, action:, actor: current_user, comment: params[:comment])
      redirect_to admin_workflow_request_path(@workflow_request), notice: "申請を処理しました。"
    rescue ActiveRecord::RecordInvalid => e
      redirect_to admin_workflow_request_path(@workflow_request), alert: "処理に失敗しました: #{e.message}"
    end
  end
end
