module Admin
  class WorkflowStageTemplatesController < BaseController
    before_action :set_category
    before_action :set_stage_template, only: [:update, :destroy]

    def create
      @stage_template = @workflow_category.stage_templates.build(stage_template_params)
      if @stage_template.save
        redirect_to admin_workflow_category_path(@workflow_category), notice: "承認ステップを追加しました。"
      else
        redirect_to admin_workflow_category_path(@workflow_category), alert: "承認ステップの追加に失敗しました。"
      end
    end

    def update
      if @stage_template.update(stage_template_params)
        redirect_to admin_workflow_category_path(@workflow_category), notice: "承認ステップを更新しました。"
      else
        redirect_to admin_workflow_category_path(@workflow_category), alert: "承認ステップの更新に失敗しました。"
      end
    end

    def destroy
      @stage_template.destroy
      redirect_to admin_workflow_category_path(@workflow_category), notice: "承認ステップを削除しました。"
    end

    private

    def set_category
      @workflow_category = WorkflowCategory.find(params[:workflow_category_id])
    end

    def set_stage_template
      @stage_template = @workflow_category.stage_templates.find(params[:id])
    end

    def stage_template_params
      params.require(:workflow_stage_template).permit(:position, :name, :responsible_role, :responsible_user_id, :instructions)
    end
  end
end
